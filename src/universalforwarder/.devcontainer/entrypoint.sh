#!/bin/bash
set -e

if [ -z "${SPLUNK_PASSWORD}" ]; then
    echo "The environment variable SPLUNK_PASSWORD must be set."
    exit 1
fi

if [ ! -f ${SPLUNK_HOME}/etc/passwd ]; then
  mkdir -p ${SPLUNK_HOME}/etc/system/local
  seed="[user_info]\nUSERNAME = admin\nPASSWORD = ${SPLUNK_PASSWORD}\n"
  printf "$seed" | sudo -HEu ${SPLUNK_USER} tee "${SPLUNK_HOME}/etc/system/local/user-seed.conf" > /dev/null
fi

if [[ "$SPLUNK_START_ARGS" != *"--accept-license"* ]]; then
  printf "License not accepted, please adjust SPLUNK_START_ARGS to indicate you have accepted the license.\n"
  printf "The license you are accepting is the Splunk General Terms, available here: https://www.splunk.com/en_us/legal/splunk-general-terms.html\n"
  printf "Unless you have jointly executed with Splunk a negotiated version of these General Terms that explicitly supersedes this agreement, by accessing or using Splunk software, you are agreeing to the Splunk General Terms.\n"
  printf "Please read and make sure you agree to the Splunk General Terms before you access or use this software.\n"
  printf "Only once you've done so should you include the '--accept-license' flag to indicate your acceptance of the Splunk General Terms and launch this software.\n"
  exit 1
fi

# universalforwarder 9.1+ refuses to start without systemctl
# reverts https://github.com/devcontainers/features/blob/da45251310a057c03dbe08477fb43f91f574361f/src/common-utils/main.sh#L593-L597
cp /bin/systemctl /usr/local/bin/systemctl

sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk start ${SPLUNK_START_ARGS} --no-prompt --answer-yes
sleep inf
