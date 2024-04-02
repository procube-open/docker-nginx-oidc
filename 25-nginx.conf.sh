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
        '"role1": "$oidc_role1",'
        '"role2": "$oidc_role2",'
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

if [ -n "${OIDC_REDIRECT_SCHEME}" ]; then
    echo "env OIDC_REDIRECT_SCHEME=${OIDC_REDIRECT_SCHEME};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_TOP_PAGE_URL_PATTERN0}" ]; then
    echo "env OIDC_TOP_PAGE_URL_PATTERN0=${OIDC_TOP_PAGE_URL_PATTERN0};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_TOP_PAGE_URL_PATTERN1}" ]; then
    echo "env OIDC_TOP_PAGE_URL_PATTERN1=${OIDC_TOP_PAGE_URL_PATTERN1};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_TOP_PAGE_URL_PATTERN2}" ]; then
    echo "env OIDC_TOP_PAGE_URL_PATTERN2=${OIDC_TOP_PAGE_URL_PATTERN2};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_TOP_PAGE_URL_PATTERN3}" ]; then
    echo "env OIDC_TOP_PAGE_URL_PATTERN3=${OIDC_TOP_PAGE_URL_PATTERN3};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_TOKEN_ENDPOINT}" ]; then
    echo "env OIDC_TOKEN_ENDPOINT=${OIDC_TOKEN_ENDPOINT};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_CLIENT_ID}" ]; then
    echo "env OIDC_CLIENT_ID=${OIDC_CLIENT_ID};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_CLIENT_SECRET}" ]; then
    echo "env OIDC_CLIENT_SECRET=${OIDC_CLIENT_SECRET};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${JWT_GEN_KEY}" ]; then
    echo "env JWT_GEN_KEY=${JWT_GEN_KEY};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_COOKIE_OPTIONS}" ]; then
    echo "env OIDC_COOKIE_OPTIONS=${OIDC_COOKIE_OPTIONS};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_USER_CLAIM}" ]; then
    echo "env OIDC_USER_CLAIM=${OIDC_USER_CLAIM};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_GROUP_CLAIM}" ]; then
    echo "env OIDC_GROUP_CLAIM=${OIDC_GROUP_CLAIM};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_ROLE1_CLAIM}" ]; then
    echo "env OIDC_ROLE1_CLAIM=${OIDC_ROLE1_CLAIM};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_ROLE2_CLAIM}" ]; then
    echo "env OIDC_ROLE2_CLAIM=${OIDC_ROLE2_CLAIM};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_CLIENTCERT_VALIDATE_URL}" ]; then
    echo "env OIDC_CLIENTCERT_VALIDATE_URL=${OIDC_CLIENTCERT_VALIDATE_URL};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_STATIONAY_TOKEN_SPAN}" ]; then
    echo "env OIDC_STATIONAY_TOKEN_SPAN=${OIDC_STATIONAY_TOKEN_SPAN};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_SCOPE}" ]; then
    echo "env OIDC_SCOPE=${OIDC_SCOPE};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_CLIENT_ID}" ]; then
    echo "env OIDC_CLIENT_ID=${OIDC_CLIENT_ID};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_AUTH_ENDPOINT}" ]; then
    echo "env OIDC_AUTH_ENDPOINT=${OIDC_AUTH_ENDPOINT};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_LOGOUT_ENDPOINT}" ]; then
    echo "env OIDC_LOGOUT_ENDPOINT=${OIDC_LOGOUT_ENDPOINT};" >> /etc/nginx/conf.d/envs.conf
fi
if [ -n "${OIDC_POSTLOGOUT_CONTENT}" ]; then
    echo "env OIDC_POSTLOGOUT_CONTENT=${OIDC_POSTLOGOUT_CONTENT};" >> /etc/nginx/conf.d/envs.conf
fi
