FROM nginx:1.25
RUN sed -i -e "8i load_module modules/ngx_http_js_module.so;" /etc/nginx/nginx.conf
COPY templates/ /etc/nginx/templates/
COPY conflib/ /etc/nginx/conflib/
COPY njs/ /etc/nginx/njs/