#!/bin/bash
# Compare image size, startup time, CPU and memory of Splunk images.
# Usage: benchmark.sh <label>=<image> [<label>=<image> ...]
# MODE=size reports download size (from the registry, or a gzip estimate for local builds) and unpacked size.
# MODE=startup starts each image on its own RUNS times (first start, then a restart), in random order.
# MODE=idle starts every image at once, lets them settle and samples their idle CPU and memory.
# MODE takes a comma-separated list, or all (default). Raw results go to $OUT-<mode>.tsv,
# and a Markdown summary (median, min–max) to stdout.
set -euo pipefail

MODE=${MODE:-all}
RUNS=${RUNS:-5}
SETTLE=${SETTLE:-180}
SAMPLE=${SAMPLE:-300}
CPUS=${CPUS:-4}
MEMORY=${MEMORY:-6g}
TIMEOUT=${TIMEOUT:-900}
OUT=${OUT:-benchmark}
PASSWORD=splunkdev

size_columns=(label download unpacked)
size_headers=("Download (MB)" "Unpacked (MB)")
startup_columns=(label run first_up first_ready first_cpu restart_ready restart_cpu)
startup_headers=("First start: up (s)" "First start: ready (s)" "First start CPU (s)" "Restart: ready (s)" "Restart CPU (s)")
idle_columns=(label idle_cpu total working_set anon peak procs)
idle_headers=("Idle CPU (%)" "Memory incl. cache (MB)" "Working set (MB)" "Anonymous memory (MB)" "Peak memory (MB)" "Processes")

log() { echo "[$(date +%T)] $*" >&2; }
die() { echo "$*" >&2; exit 1; }
has_mode() { [ "$MODE" = all ] || [[ ",$MODE," == *",$1,"* ]]; }
now() { date +%s.%N; }
since() { awk -v s="$1" -v n="$(now)" 'BEGIN { printf "%.1f", n - s }'; }
cg() { docker exec "$name" cat "/sys/fs/cgroup/$1"; }
cpu_seconds() { cg cpu.stat | awk '/^usage_usec/ { printf "%.1f", $2 / 1e6 }'; }
stat_mb() { cg memory.stat | awk -v k="$1" '$1 == k { printf "%.0f", $2 / 1048576 }'; }
image_env() { docker image inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$1" | sed -n "s/^$2=//p"; }
host_port() { docker port "$name" "$1/tcp" | head -1 | sed 's/.*://'; }

# Splunk answers: REST on 8089 for Enterprise, the CLI for the forwarder (10.x has no TCP management port by default)
is_up() {
  if [ "$kind" = enterprise ]; then
    [ "$(curl -sk -m 2 -u "admin:$PASSWORD" -o /dev/null -w '%{http_code}' "https://127.0.0.1:$(host_port 8089)/services/server/info")" = 200 ]
  else
    timeout 10 docker exec -u splunk "$name" "$home/bin/splunk" list forward-server -auth "admin:$PASSWORD" \
      --no-prompt </dev/null >/dev/null 2>&1
  fi
}

web_up() {
  local scheme port
  port=$(host_port 8000)
  for scheme in http https; do
    [ "$(curl -skL -m 2 -o /dev/null -w '%{http_code}' "$scheme://127.0.0.1:$port/en-US/account/login")" = 200 ] && return 0
  done
  return 1
}

# The official images keep configuring Splunk with Ansible after splunkd starts
provisioned() {
  [ "$official" = no ] || [ "$(docker exec "$name" cat "$artifacts/splunk-container.state" 2>/dev/null)" = started ]
}

# Sets t_up and t_ready (seconds since $1)
wait_ready() {
  local start=$1 up= web=
  [ "$kind" = enterprise ] || web=skip
  t_up= t_ready=
  while :; do
    [ -z "$up" ] && is_up && up=1 && t_up=$(since "$start")
    [ -z "$web" ] && web_up && web=1
    if [ -n "$up" ] && [ -n "$web" ] && provisioned && is_up; then
      t_ready=$(since "$start")
      return
    fi
    if [ "$(docker inspect -f '{{.State.Running}}' "$name")" != true ] || [ "$(printf '%.0f' "$(since "$start")")" -gt "$TIMEOUT" ]; then
      log "$label: container exited or timed out after ${TIMEOUT}s"
      docker logs --tail 30 "$name" >&2
      return 1
    fi
    sleep 1
  done
}

# Sets the container and image details for image number $1
use() {
  label=${specs[$1]%%=*} image=${specs[$1]#*=} home=${homes[$1]} artifacts=${artifact_dirs[$1]}
  name=splunk-benchmark-$RUN_ID-$1
  kind=enterprise official=no
  if [ "$home" = /opt/splunkforwarder ]; then kind=uf; fi
  if [ -n "$artifacts" ]; then official=yes; fi
}

start_container() {
  local args=(--name "$name" --label "splunk-benchmark=$RUN_ID" --cpus "$CPUS" --memory "$MEMORY" --memory-swap "$MEMORY"
    -e SPLUNK_START_ARGS=--accept-license -e SPLUNK_PASSWORD=$PASSWORD
    -e SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com
    -p 127.0.0.1::8089)
  if [ "$kind" = enterprise ]; then args+=(-p 127.0.0.1::8000); fi
  docker run -d "${args[@]}" "$image" >/dev/null
}

stop_container() {
  [ "$official" = no ] || docker exec "$name" sh -c "echo stopped > $artifacts/splunk-container.state"
  # Our entrypoint doesn't forward SIGTERM, so stop Splunk the same way in every image
  docker exec -u splunk "$name" "$home/bin/splunk" stop >/dev/null
  docker stop -t 30 "$name" >/dev/null
}

# One startup run of image $1: first start, then a restart on the same volumes
startup() {
  local start first_up first_ready first_cpu
  use "$1"
  log "$label (run $2): first start"
  start=$(now)
  start_container
  wait_ready "$start"
  first_up=$t_up first_ready=$t_ready first_cpu=$(cpu_seconds)

  log "$label (run $2): restart"
  stop_container
  start=$(now)
  docker start "$name" >/dev/null
  wait_ready "$start"
  printf '%s\t' "$label" "$2" "$first_up" "$first_ready" "$first_cpu" "$t_ready"
  printf '%s\n' "$(cpu_seconds)"
  docker rm -fv "$name" >/dev/null
}

# Starts every image at once and samples each container's own cgroup
idle() {
  local i n=0 c0=() t0=() total=() working_set=() anon=() current
  log "idle: starting every image"
  for i in "${!specs[@]}"; do use "$i"; start_container; done
  for i in "${!specs[@]}"; do use "$i"; wait_ready "$(now)"; done

  log "idle: settling for ${SETTLE}s, then sampling for ${SAMPLE}s"
  sleep "$SETTLE"
  for i in "${!specs[@]}"; do
    use "$i"
    c0[i]=$(cpu_seconds) t0[i]=$(now) total[i]=0 working_set[i]=0 anon[i]=0
  done
  while :; do
    for i in "${!specs[@]}"; do
      use "$i"
      current=$(($(cg memory.current) / 1048576))
      total[i]=$((total[i] + current))
      working_set[i]=$((working_set[i] + current - $(stat_mb inactive_file)))
      anon[i]=$((anon[i] + $(stat_mb anon)))
    done
    n=$((n + 1))
    [ "$(printf '%.0f' "$(since "${t0[0]}")")" -lt "$SAMPLE" ] || break
    sleep 5
  done
  for i in "${!specs[@]}"; do
    use "$i"
    printf '%s\t' "$label" \
      "$(awk -v c0="${c0[i]}" -v c1="$(cpu_seconds)" -v t0="${t0[i]}" -v t1="$(now)" 'BEGIN { printf "%.1f", (c1 - c0) / (t1 - t0) * 100 }')" \
      "$((total[i] / n))" "$((working_set[i] / n))" "$((anon[i] / n))" "$(($(cg memory.peak) / 1048576))"
    # Counted from the host, so the probe doesn't add processes inside the container
    docker top "$name" -eo pid | tail -n +2 | wc -l
  done
}

# Download size is exact for pulled images (registry manifest, amd64) and a gzip estimate (~) for local builds
size() {
  local image=${specs[$1]#*=} dir layer download= compressed=0 unpacked=0 digest gz=gzip
  if command -v pigz >/dev/null; then gz=pigz; fi
  digest=$(docker image inspect -f '{{range .RepoDigests}}{{println .}}{{end}}' "$image" | head -1)
  if [ -n "$digest" ]; then
    download=$(docker manifest inspect -v "$digest" 2>/dev/null | jq 'if type == "array"
      then map(select(.Descriptor.platform.architecture == "amd64"))[0] else . end
      | [(.OCIManifest // .SchemaV2Manifest).layers[].size] | add / 1000000 | floor' || true)
  fi
  dir=$(mktemp -d)
  docker save "$image" | tar -x -C "$dir"
  for layer in $(jq -r '.[0].Layers[]' "$dir/manifest.json"); do
    if [ "$(head -c 2 "$dir/$layer" | od -An -tx1 | tr -d ' \n')" = 1f8b ]; then
      compressed=$((compressed + $(stat -c %s "$dir/$layer")))
      unpacked=$((unpacked + $("$gz" -dc "$dir/$layer" | wc -c)))
    else
      [ -n "$download" ] || compressed=$((compressed + $("$gz" -c "$dir/$layer" | wc -c)))
      unpacked=$((unpacked + $(stat -c %s "$dir/$layer")))
    fi
  done
  rm -rf "$dir"
  printf '%s\t%s\t%s\n' "${specs[$1]%%=*}" "${download:-~$((compressed / 1000000))}" "$((unpacked / 1000000))"
}

# Markdown table of the median (min–max) per image: <file> <headers array name>
summary() {
  local file=$1 i c nf label values min max
  local -n hdr=$2
  nf=$(head -1 "$file" | awk -F '\t' '{ print NF }')
  printf '| Image |'
  printf ' %s |' "${hdr[@]}"
  printf '\n|---|'
  printf -- '--:|%.0s' "${hdr[@]}"
  echo
  for i in "${!specs[@]}"; do
    label=${specs[i]%%=*}
    printf '| %s |' "$label"
    for c in $(seq $((nf - ${#hdr[@]} + 1)) "$nf"); do
      values=$(awk -F '\t' -v l="$label" -v c="$c" 'NR > 1 && $1 == l { print $c }' "$file" | sort -n)
      min=$(head -1 <<< "$values") max=$(tail -1 <<< "$values")
      if [ "$min" = "$max" ]; then
        printf ' %s |' "$min"
      else
        printf ' %s (%s–%s) |' "$(awk '{ v[NR] = $1 } END { print (NR % 2 ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2) }' <<< "$values")" "$min" "$max"
      fi
    done
    echo
  done
}

[ $# -gt 0 ] || { sed -n 2,8p "$0" | cut -c 3-; exit 1; }
[[ "$MODE" =~ ^(all|(size|startup|idle)(,(size|startup|idle))*)$ ]] || die "MODE must be all or a comma-separated list of size, startup and idle"
for setting in RUNS SAMPLE TIMEOUT; do
  [[ "${!setting}" =~ ^[1-9][0-9]*$ ]] || die "$setting must be a positive whole number of seconds or runs"
done
[[ "$SETTLE" =~ ^[0-9]+$ ]] || die "SETTLE must be a whole number of seconds"
for spec in "$@"; do
  [[ "$spec" == ?*=?* ]] || die "Expected <label>=<image>, got $spec"
done
RUN_ID=$$-$(date +%s)
trap 'docker ps -aq --filter "label=splunk-benchmark=$RUN_ID" | xargs -r docker rm -fv >/dev/null' EXIT

specs=("$@") homes=() artifact_dirs=()
for i in "${!specs[@]}"; do
  image=${specs[i]#*=}
  docker image inspect "$image" >/dev/null 2>&1 || docker pull -q "$image" >/dev/null
  if has_mode startup || has_mode idle; then
    log "${specs[i]%%=*}: warming up (reading the image once)"
    docker run --rm --entrypoint sh "$image" -c 'tar -cf - /opt 2>/dev/null | wc -c' >/dev/null
  fi
  homes[i]=$(image_env "$image" SPLUNK_HOME)
  artifact_dirs[i]=$(image_env "$image" CONTAINER_ARTIFACT_DIR)
done

if has_mode size; then
  (IFS=$'\t'; echo "${size_columns[*]}") > "$OUT-size.tsv"
  for i in "${!specs[@]}"; do
    log "${specs[i]%%=*}: size"
    size "$i" | tee -a "$OUT-size.tsv" >&2
  done
  printf '### Size\n\nDownload size is the compressed amd64 layers; ~ marks a gzip estimate for images not pulled from a registry.\n\n'
  summary "$OUT-size.tsv" size_headers
  echo
fi

if has_mode startup; then
  (IFS=$'\t'; echo "${startup_columns[*]}") > "$OUT-startup.tsv"
  for run in $(seq "$RUNS"); do
    for i in $(shuf -e "${!specs[@]}"); do
      startup "$i" "$run" | tee -a "$OUT-startup.tsv" >&2
    done
  done
  printf '### Startup\n\n%s runs per image, one container at a time.\n\n' "$RUNS"
  summary "$OUT-startup.tsv" startup_headers
  echo
fi

if has_mode idle; then
  (IFS=$'\t'; echo "${idle_columns[*]}") > "$OUT-idle.tsv"
  idle | tee -a "$OUT-idle.tsv" >&2
  printf '### Idle\n\nAll images running at once, sampled for %ss after %ss to settle.\n\n' "$SAMPLE" "$SETTLE"
  summary "$OUT-idle.tsv" idle_headers
fi
