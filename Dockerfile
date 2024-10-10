FROM nginx:1.25

# Build nginx code copied from official nginx Dockerfile
# https://github.com/nginxinc/docker-nginx/blob/master/stable/debian/Dockerfile
# to add ngx_upstream_jdomain module(updated)
# ENV UPSTREAM_JDOMAIN_VERSION=1.5.0
ENV UPSTREAM_JDOMAIN_VERSION=preserve-peer-state2

COPY fail_timeout_30.patch /tmp/

RUN set -x \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published packaging sources
# new directory for storing sources and .deb files
&& tempDir="$(mktemp -d)" \
&& chmod 777 "$tempDir" \
# (777 to ensure APT's "_apt" user can access it too)
\
# save list of currently-installed packages so build dependencies can be cleanly removed later
&& savedAptMark="$(apt-mark showmanual)" \
\
# build .deb files from upstream's packaging sources
&& apt-get update \
&& apt-get install --no-install-recommends --no-install-suggests -y \
    curl \
    devscripts \
    equivs \
    git \
    unzip \
    libxml2-utils \
    lsb-release \
    xsltproc \
&& ( \
    cd "$tempDir" \
    && curl -f -L -o ngx_upstream_jdomain-${UPSTREAM_JDOMAIN_VERSION}.zip https://github.com/procube-sandbox/ngx_upstream_jdomain/archive/refs/heads/${UPSTREAM_JDOMAIN_VERSION}.zip \
    && unzip ngx_upstream_jdomain-${UPSTREAM_JDOMAIN_VERSION}.zip \
    && (cd ngx_upstream_jdomain-${UPSTREAM_JDOMAIN_VERSION} && patch -p1 < /tmp/fail_timeout_30.patch) \
    && REVISION="${NGINX_VERSION}-${PKG_RELEASE}" \
    && REVISION=${REVISION%~*} \
    && curl -f -L -O https://github.com/nginx/pkg-oss/archive/${REVISION}.tar.gz \
    && PKGOSSCHECKSUM="4db34369291ce5d4eed16006d571711da5c4e3e6c7702813ccd36fecc04355e1ec24c69406b66d13b431a25ec9593025c6842643823287eda58e235c9542f5f4 *${REVISION}.tar.gz" \
    && if [ "$(openssl sha512 -r ${REVISION}.tar.gz)" = "$PKGOSSCHECKSUM" ]; then \
        echo "pkg-oss tarball checksum verification succeeded!"; \
    else \
        echo "pkg-oss tarball checksum verification failed!"; \
        exit 1; \
    fi \
    && tar xzvf ${REVISION}.tar.gz \
    && cd pkg-oss-${REVISION} \
    && cd debian \
    && sed -i 's/BASE_CONFIGURE_ARGS=\\/BASE_CONFIGURE_ARGS=--add-module='$(echo $tempDir | sed 's/\//\\\//g')'\/ngx_upstream_jdomain-'${UPSTREAM_JDOMAIN_VERSION}' \\/' Makefile \
    && make rules-base \
    && mk-build-deps --install --tool="apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes" \
            debuild-base/nginx-$NGINX_VERSION/debian/control \
    && make base \
) \
# we don't remove APT lists here because they get re-downloaded and removed later
\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
# (which is done after we install the built packages so we don't have to redownload any overlapping dependencies)
&& apt-mark showmanual | xargs apt-mark auto > /dev/null \
&& { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; } \
\
# create a temporary local APT repo to install from (so that dependency resolution can be handled by APT, as it should be)
&& ls -lAFh "$tempDir" \
&& ( cd "$tempDir" && dpkg-scanpackages . > Packages ) \
&& grep '^Package: ' "$tempDir/Packages" \
&& echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list \
# work around the following APT issue by using "Acquire::GzipIndexes=false" (overriding "/etc/apt/apt.conf.d/docker-gzip-indexes")
#   Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
#   ...
#   E: Failed to fetch store:/var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages  Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
&& apt-get -o Acquire::GzipIndexes=false update \
\
&& apt-get install --no-install-recommends --no-install-suggests -y \
            nginx \
            gettext-base \
            curl \
&& apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list

# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
# && if [ -n "$tempDir" ]; then \
# apt-get purge -y --auto-remove \
# && rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
# fi

RUN apt update && apt install -y supervisor cron logrotate

# supervisord
CMD ["supervisord", "--nodaemon"]
COPY supervisor /etc/logrotate.d/

# cron & logrotate
COPY cron.conf /etc/supervisor/conf.d/
RUN rm -rf /etc/cron.* && \
    echo '0 1 * * * root /usr/sbin/logrotate /etc/logrotate.conf' > /etc/crontab
COPY 50-TZ.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.d/50-TZ.sh

# nginx
COPY conflib/ /etc/nginx/conflib/
COPY njs/ /etc/nginx/njs/
COPY nginx.conf /etc/supervisor/conf.d/
RUN rm -f /var/log/nginx/*.log
RUN chown nginx:nginx /var/log/nginx
COPY docker-entrypoint.sh /
COPY 25-nginx.conf.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.sh /docker-entrypoint.d/25-nginx.conf.sh

# avoid message: testing "/etc/nginx/html" existence failed (2: No such file or directory) while logging request
# https://serverfault.com/questions/808560/what-does-existence-failed-20-not-a-directory-while-logging-request-error-l
RUN mkdir /etc/nginx/html

# fluentd
RUN apt install -y sudo make gcc && \
    curl -fsSL https://toolbelt.treasuredata.com/sh/install-debian-bookworm-fluent-package5-lts.sh | sh && \
    curl -L https://www.mongodb.org/static/pgp/server-7.0.asc -o /etc/apt/trusted.gpg.d/server-7.0.asc  && \
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list && \
    apt update && apt install -y mongodb-mongosh
ENV GEM_HOME=/opt/fluent/lib/ruby/gems/3.2.0/
ENV PATH="/opt/fluent/bin:${PATH}"
RUN gem update fluentd
RUN /opt/fluent/lib/ruby/gems/3.2.0/bin/fluent-gem install fluent-plugin-mongo
COPY 70-fluentd.conf.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.d/70-fluentd.conf.sh

# Return 400 default
COPY default.conf /etc/nginx/conf.d/

ENV OIDC_COOKIE_OPTIONS="; Path=/; secure; httpOnly"
ENV OIDC_STATIONAY_TOKEN_SPAN=600
