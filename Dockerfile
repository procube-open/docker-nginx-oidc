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
COPY templates/ /etc/nginx/templates/
COPY conflib/ /etc/nginx/conflib/
COPY njs/ /etc/nginx/njs/
COPY nginx.conf /etc/supervisor/conf.d/
COPY templates/ /etc/nginx/templates/
COPY docker-entrypoint.sh /
RUN rm -f /var/log/nginx/*.log
RUN chmod +x /docker-entrypoint.sh
