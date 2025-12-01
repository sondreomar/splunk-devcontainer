ARG BASE_IMAGE=buildpack-deps:bookworm-curl

FROM ${BASE_IMAGE} AS package

# https://www.splunk.com/en_us/download/splunk-enterprise.html
ARG SPLUNK_VERSION
ARG SPLUNK_BUILD
ARG SPLUNK_PLATFORM

ENV PACKAGE=splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-${SPLUNK_PLATFORM}.tgz
ENV PACKAGE_URL=https://download.splunk.com/products/splunk/releases/${SPLUNK_VERSION}/linux/${PACKAGE}

WORKDIR /tmp

ADD ${PACKAGE_URL} ${PACKAGE}
ADD ${PACKAGE_URL}.sha512 ${PACKAGE}.sha512

COPY ["splunk_exclude", "/tmp/"]

RUN echo "$(cat ${PACKAGE}.sha512)" | sha512sum --check --status \
    && mkdir -p /package/splunk \
    && tar -C /package/splunk --strip 1 --exclude-from=splunk_exclude -zxf ${PACKAGE} \
    && touch /package/splunk/etc/.ui_login \
    && mkdir -p /package/splunk/etc/system/local \
    && printf "[system_checks]\ninstalled_files_integrity = disabled\n" >> /package/splunk/etc/system/local/limits.conf \
    && mkdir -p /package/splunk/etc/apps/user-prefs/local \
    && printf "[general]\nhideInstrumentationOptInModal=1\n" > /package/splunk/etc/apps/user-prefs/local/user-prefs.conf \
    && mkdir -p /package/splunk/etc/users/admin/search/local \
    && printf "[search-tour]\nviewed = 1\n[dark-tour]\nviewed = 1\n[dashboards-tour:enterprise]\nviewed = 1\n" >> /package/splunk/etc/users/admin/search/local/ui-tour.conf

FROM ${BASE_IMAGE} AS base

ENV SPLUNK_HOME=/opt/splunk
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

EXPOSE 8000/tcp 8089/tcp

COPY [ "entrypoint.sh", "/sbin/" ]
RUN chmod +x /sbin/entrypoint.sh
ENTRYPOINT [ "/sbin/entrypoint.sh" ]
