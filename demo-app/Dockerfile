FROM nginx:stable-alpine

COPY index.html error.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.sh /

ENTRYPOINT ["sh", "docker-entrypoint.sh"]
