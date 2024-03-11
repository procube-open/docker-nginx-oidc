FROM nginx:1.25

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
ENV GEM_HOME /opt/fluent/lib/ruby/gems/3.2.0/
ENV PATH="/opt/fluent/bin:${PATH}"
RUN /opt/fluent/lib/ruby/gems/3.2.0/bin/fluent-gem install fluent-plugin-mongo
COPY 70-fluentd.conf.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.d/70-fluentd.conf.sh

# Return 400 default
COPY default.conf /etc/nginx/conf.d/

ENV OIDC_COOKIE_OPTIONS "; Path=/; secure; httpOnly"
ENV OIDC_STATIONAY_TOKEN_SPAN 600
