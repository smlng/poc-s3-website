FROM openresty/openresty:alpine
RUN apk add --no-cache \
    lua-resty-http \
    lua-resty-hmac \
    lua-resty-openssl \
    lua-resty-string

RUN mkdir -p /etc/nginx/lua
RUN mkdir -p /etc/nginx/conf.d
