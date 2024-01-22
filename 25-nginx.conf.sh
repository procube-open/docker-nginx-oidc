#!/bin/sh
# vim:sw=4:ts=4:et

set -e

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

export NGINX_LOG_LEVEL=${NGINX_LOG_LEVEL:-notice}

if [ -z "${NGINX_LOCAL_RESOLVERS}" ]; then
    entrypoint_log "$ME: error: Environment variable NGINX_LOCAL_RESOLVERS must be set."
    exit 1
fi

entrypoint_log "$ME: info: put /etc/nginx/nginx.conf."

envsubst '${NGINX_LOG_LEVEL} ${NGINX_LOCAL_RESOLVERS}' > /etc/nginx/nginx.conf << 'EOF'
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log ${NGINX_LOG_LEVEL};
pid        /var/run/nginx.pid;

load_module modules/ngx_http_js_module.so;

events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;
    resolver ${NGINX_LOCAL_RESOLVERS};

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