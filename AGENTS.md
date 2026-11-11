# AGENTS.md

Devcontainer images for local Splunk development, published to `ghcr.io/sondreomar/splunk-devcontainer`.

## Layout

- `src/splunk/.devcontainer/` – Splunk Enterprise image (Dockerfile, entrypoint, `splunk_exclude`). Built twice: the full image, and a slim image (`SPLUNK_SLIM=true`, `-slim` tag suffix) that leaves out everything matched by `splunk_exclude`.
- `src/universalforwarder/.devcontainer/` – Universal Forwarder image, published with the `-uf` tag suffix.
- `.github/splunk-versions.json` – every supported Splunk version (`version`, `build`, `platform`).
- `.github/workflows/` – `prepare.yml` works out tags and which versions to build, `build-image.yml` builds and pushes one variant (`splunk`, `splunk-slim` or `universalforwarder`), `test.yml` runs on PRs, and `release.yml` runs on `vX.Y.Z` git tags.
  - Each variant has its own matrix, so the 256-jobs-per-matrix limit applies per variant. Releases build one variant at a time with up to 15 builds in parallel, and tests build all variants at once with up to 6 each, so other workflows still get runners.
  - Releases build the versions added since the previous release tag. If `src/` or `build-image.yml` changed since then, they also rebuild the newest version in each minor line.
  - PRs build the newest version in each minor line, plus any versions the PR adds.
  - Dispatch `release.yml` (on a tag) or `test.yml` with `all_versions` to build every version. `release.yml` also takes a `variant` input to rebuild only one variant, e.g. every slim image after a slim-only change.
- `examples/` – example devcontainer setups. The images aren't built from these.
- `.devcontainer/` – devcontainer for working on this repo. It builds `src/splunk` with a pinned version.

## Conventions

- Keep both variants in sync. A change to one Dockerfile, entrypoint or `devcontainer.json` usually belongs in the other too. Known intentional differences:
  - Only the Enterprise image has a slim variant and seeds UI config.
  - Only the forwarder image installs `systemd`, because the forwarder won't start without it.
- Don't disable Splunk's `installed_files_integrity` check. The Dockerfile drops files that weren't extracted from Splunk's manifest instead, so anything added to `splunk_exclude` is handled automatically.
- Pin GitHub Actions to a full commit SHA, with the version in a trailing comment (`uses: foo/bar@<sha> # vX.Y.Z`). Dependabot keeps them updated.
- Pin devcontainer feature versions, e.g. `common-utils:2.5.7`.
- Use Conventional Commits: `feat:`, `fix(ci):`, `ci:`, `chore:`. Dependabot uses `ci(deps):` and `docker(deps):`.
- If you change the tag scheme, update the README "Image Tags" section in the same change.

## Splunk versions

- Enterprise and the Universal Forwarder use the same build ID for a given version.
- `platform` is `Linux-x86_64` for 9.3.x and `linux-amd64` from 9.4.0 onwards.
- Keep entries sorted by version.
- Splunk also ships four-part maintenance versions (e.g. `10.6.1.1`). Splunk's own `X.Y.Z` Docker tag points to the latest `X.Y.Z.N`, and our images follow the same pattern.

### Finding new builds

1. Fetch `https://www.splunk.com/en_us/download/splunk-enterprise.html` and `.../previous-releases.html` with a browser User-Agent. Then grep the raw HTML for `releases/<version>/linux/splunk-<version>-<build>-<platform>.tgz`.
2. If a version isn't listed there, read its build ID from Splunk's own Docker image instead:
   1. Pull the manifest for `splunk/universalforwarder:<version>` (amd64).
   2. Stream its largest layer (~170 MB).
   3. Read `BUILD=` from `opt/splunkforwarder-etc/splunk.version`.

   The image config, labels and the docker-splunk repo don't contain the build ID.
3. Check that both the Enterprise `.tgz` and the forwarder `.tgz`, plus their `.sha512` files, return HTTP 200 on `download.splunk.com`. The Dockerfiles verify the checksum during the build.

## Tags

For each built version, `build-image.yml` adds these floating tags, each with a `-slim` variant for the slim Enterprise image and a `-uf` variant for the forwarder:

| Tag      | Points to                         |
| -------- | --------------------------------- |
| `X.Y.Z`  | latest `X.Y.Z.N`                  |
| `X.Y`    | latest version in that minor line |
| `X`      | latest version in that major line |
| `latest` | latest version overall            |

The version tags (including the full `X.Y.Z.N` tag) also get `-v<image version>`, `-v<image minor>` and `-v<image major>` variants, e.g. `10.6-uf-v1.2.3` or `10.6-slim-v1.2.3`. `latest`, `latest-slim` and `latest-uf` don't, so tags like `latest-v1.2.3` don't exist.

The tags are worked out from every version in `splunk-versions.json`, and only the build of the version a tag points to pushes it. Building only some versions therefore never moves a tag to an older version. A plain `X.Y.Z` is left out of the build when an `X.Y.Z.N` exists, so two builds never push the same tag.

## Building locally

```sh
SPLUNK_VERSION=10.6.1.1 SPLUNK_BUILD=b2ae2962645c SPLUNK_PLATFORM=linux-amd64 \
  devcontainer build --workspace-folder src/splunk --image-name splunk-devcontainer:local
```

Add `SPLUNK_SLIM=true` for the slim image, or use `src/universalforwarder` for the forwarder. The tag logic in `prepare.yml` and `build-image.yml` is plain `jq`, so you can test it locally by passing the JSON file through the same filters.
