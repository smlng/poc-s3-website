FROM openresty/openresty:alpine
RUN apk add --no-cache \
            luarocks5.1

RUN luarocks-5.1 install lua-resty-aws-signature \
 && luarocks-5.1 install lua-resty-http

RUN mkdir -p /etc/nginx/lua
RUN mkdir -p /etc/nginx/conf.d
