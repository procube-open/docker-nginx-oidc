#!/bin/sh
# vim:sw=4:ts=4:et

set -e

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

if [ "${NGINX_CONFIGURE_FLUENTD}" != "true" ]; then
    entrypoint_log "$ME: info: Environment variable NGINX_CONFIGURE_FLUENTD != 'true', so do not configure fluentd."
    exit 0
fi

entrypoint_log "$ME: info: register fluentd to supervisord."

cat > /etc/supervisor/conf.d/fluentd.conf << 'EOF'
[program:fluentd]
environment=LD_PRELOAD=/opt/fluent/lib/libjemalloc.so,GEM_HOME=/opt/fluent/lib/ruby/gems/3.2.0/,GEM_PATH=/opt/fluent/lib/ruby/gems/3.2.0/,FLUENT_CONF=/etc/fluent/fluentd.conf,FLUENT_PLUGIN=/etc/fluent/plugin,FLUENT_SOCKET=/var/run/fluent/fluentd.sock,FLUENT_PACKAGE_LOG_FILE=/var/log/fluent/fluentd.log
command=/opt/fluent/bin/fluentd --log /var/log/fluent/fluentd.log --daemon /var/run/fluent/fluentd.pid
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log
autorestart=true
user=_fluentd
EOF

mkdir -p /etc/fluent/conf.d

function build_source () {
    tag=$1
    entrypoint_log "$ME: info: put fluentd configuration for $tag."
    cat > /etc/fluent/conf.d/${tag}.conf << __EOF
<source>
  @type tail
  path /var/log/${tag}.log
  pos_file /var/log/td-agent/${tag}.log.pos
  tag ${tag}
  <parse>
    @type json
    time_type string
    time_format %d-%b-%YT%H:%M:%S+%z
    time_key time
  </parse>
</source>
__EOF
}

for tag in $(sed -n -e '/^ *# *TAG/s/^ *# *TAG *\([^ ]*\) *$/\1/p' /etc/nginx/conf.d/*.conf); do
  build_source $tag
done

entrypoint_log "$ME: info: put fluentd configuration for mongodb."

cat > /etc/fluentd/fluentd.conf << 'EOF'
@include /etc/fluentd/conf.d/*.conf

# Single MongoDB
<match *.access>
  @type mongo
  host ${LOGDB_HOST}
  port 27017
  database fluentd
  collection access

  # for capped collection
  capped
  capped_size 1024m

  # authentication
  user ${LOGDB_USER}
  password ${LOGDB_PASSWORD}

  <buffer>
    # flush
    flush_interval 10s
  </buffer>
</match>
EOF
