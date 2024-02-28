#!/bin/sh
# vim:sw=4:ts=4:et

set -e
export ME=$(basename "$0")

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

export NGINX_LOG_LEVEL=${NGINX_LOG_LEVEL:-notice}
export NGINX_RESOLVER_LINE=""
if [ -n "${NGINX_LOCAL_RESOLVERS}" ]; then
    export NGINX_RESOLVER_LINE="resolver ${NGINX_LOCAL_RESOLVERS};"
fi

entrypoint_log "$ME: info: put /etc/nginx/nginx.conf."

envsubst '${ME} ${NGINX_LOG_LEVEL} ${NGINX_RESOLVER_LINE}' > /etc/nginx/nginx.conf << 'EOF'
# This file generated from /docker-entrypoint.d/${ME}
user  nginx;
worker_processes  auto;

error_log /dev/stdout ${NGINX_LOG_LEVEL};
pid        /var/run/nginx.pid;

load_module modules/ngx_http_js_module.so;

events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    uninitialized_variable_warn off;
    server_tokens off;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    # refer: https://itnext.io/nginx-create-react-app-gzip-tripple-your-lighthouse-performance-score-in-5-minutes-627465c3f445
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 0;
    gzip_types text/plain application/javascript text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/vnd.ms-fontobject application/x-font-ttf font/opentype;

    ${NGINX_RESOLVER_LINE}

    js_path "/etc/nginx/njs/";
    js_import oidc from oidc.js;

    log_format json escape=json '{"time": "$time_iso8601",'
        '"vhost": "$host",'
        '"req": "${connection}-${connection_requests}",'
        '"user": "$oidc_user",'
        '"group": "$oidc_group",'
        '"status": "$status",'
        '"protocol": "$server_protocol",'
        '"method": "$request_method",'
        '"path": "$request_uri",'
        '"req": "$request",'
        '"size": "$body_bytes_sent",'
        '"reqtime": "$request_time",'
        '"ua": "$http_user_agent",'
        '"origin": "$http_origin",'
        '"upstreamaddr": "$upstream_addr",'
        '"upstreamtime": "$upstream_response_time",'
        '"upstreamstatus": "$upstream_status",'
        '"referrer": "$http_referer"}';
    include /etc/nginx/conf.d/*.conf;
}
EOF