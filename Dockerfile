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
RUN sed -i -e "8i load_module modules/ngx_http_js_module.so;" /etc/nginx/nginx.conf
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
RUN apt install -y sudo && \
    curl -fsSL https://toolbelt.treasuredata.com/sh/install-debian-bookworm-fluent-package5-lts.sh | sh
COPY 70-fluentd.conf.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.d/70-fluentd.conf.sh

# Return 400 default
COPY default.conf /etc/nginx/conf.d/

ENV OIDC_COOKIE_OPTIONS "; Path=/; secure; httpOnly"