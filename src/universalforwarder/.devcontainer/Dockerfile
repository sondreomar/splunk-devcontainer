ARG BASE_IMAGE=buildpack-deps:bookworm-curl

FROM ${BASE_IMAGE} AS package

# https://www.splunk.com/en_us/download/splunk-enterprise.html
ARG SPLUNK_VERSION
ARG SPLUNK_BUILD
ARG SPLUNK_PLATFORM

ENV PACKAGE=splunkforwarder-${SPLUNK_VERSION}-${SPLUNK_BUILD}-${SPLUNK_PLATFORM}.tgz
ENV PACKAGE_URL=https://download.splunk.com/products/universalforwarder/releases/${SPLUNK_VERSION}/linux/${PACKAGE}

WORKDIR /tmp

ADD ${PACKAGE_URL} ${PACKAGE}
ADD ${PACKAGE_URL}.sha512 ${PACKAGE}.sha512

RUN echo "$(cat ${PACKAGE}.sha512)" | sha512sum --check --status \
    && mkdir -p /package/splunk \
    && tar -C /package/splunk --strip 1 -zxf ${PACKAGE}

FROM ${BASE_IMAGE} AS base

# universalforwarder 9.1+ refuses to start without systemd installed, so the placeholder
# systemctl (echoing don't use systemctl) is removed and systemd reinstalled, but we
# don't actually use it or create a unit file
RUN rm -rf /usr/local/bin/systemctl \
    && apt-get update \
    && apt-get install -y --no-install-recommends systemd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV SPLUNK_HOME=/opt/splunkforwarder
ENV SPLUNK_GROUP=splunk
ENV SPLUNK_USER=splunk

VOLUME [ "${SPLUNK_HOME}/etc", "${SPLUNK_HOME}/var" ]

ARG UID=1000
ARG GID=1000

RUN groupadd -r -g ${GID} ${SPLUNK_GROUP} \
    && useradd -r -m -u ${UID} -g ${GID} -d ${SPLUNK_HOME} -s /bin/bash ${SPLUNK_USER} \
    && mkdir -p ${SPLUNK_HOME}/var \
    && chown -R ${SPLUNK_USER}:${SPLUNK_GROUP} ${SPLUNK_HOME}

COPY --from=package --chown=${SPLUNK_USER}:${SPLUNK_GROUP} /package/splunk ${SPLUNK_HOME}

EXPOSE 8089/tcp

COPY [ "entrypoint.sh", "/sbin/" ]
RUN chmod +x /sbin/entrypoint.sh
ENTRYPOINT [ "/sbin/entrypoint.sh" ]
