#!/bin/bash
# vim:sw=4:ts=4:et

set -e
ME=$(basename "$0")

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
environment=LD_PRELOAD=/opt/fluent/lib/libjemalloc.so,GEM_HOME=/opt/fluent/lib/ruby/gems/3.2.0/,GEM_PATH=/opt/fluent/lib/ruby/gems/3.2.0/,FLUENT_CONF=/etc/fluent/fluentd.conf,FLUENT_PLUGIN=/etc/fluent/plugin,FLUENT_SOCKET=/var/run/fluent/fluentd.sock
command=/opt/fluent/bin/fluentd
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
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
  path /var/log/nginx/${tag}.log
  pos_file /var/log/fluent/${tag}.log.pos
  tag ${tag}
  <parse>
    @type json
    time_type string
    time_format %Y-%m-%dT%H:%M:%S+%z
    time_key time
  </parse>
</source>
__EOF
}

for tag in $(sed -n -e '/^ *# *TAG/s/^ *# *TAG: *\([^ ]*\) *$/\1/p' /etc/nginx/conf.d/*.conf); do
  build_source $tag
done

entrypoint_log "$ME: info: put fluentd configuration for mongodb."

cat > /etc/fluent/fluentd.conf << __EOF
@include /etc/fluent/conf.d/*.conf

# Single MongoDB
<match access.*>
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
__EOF

mongosh "mongodb://${LOGDB_HOST}" -u "${LOGDB_ROOT_USER}" -p "${LOGDB_ROOT_PASSWORD}" << __EOF
use fluentd;
if (db.getUser("${LOGDB_USER}") == null) {  
  db.createUser(
    {
      user: "${LOGDB_USER}",
      pwd: "${LOGDB_PASSWORD}",
      roles: [ "readWrite" ]
    }
  );
}
__EOF