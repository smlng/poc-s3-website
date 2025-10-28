# Stage 1: prepare
FROM openresty/openresty:bullseye AS builder

# install dependencies
RUN apt update  && \
    apt install -y luarocks
RUN luarocks install lua-resty-aws-signature && \
    luarocks install lua-resty-http

# overwrite default paths in base config
RUN sed -i 's|/var/run/openresty/|/tmp/|g' /usr/local/openresty/nginx/conf/nginx.conf

# prepare binary and dependencies
RUN mkdir -p /opt/openresty-lua/share && \
    cp -r /usr/local/openresty/ /opt/openresty-lua/openresty && \
    cp -r /usr/local/share/lua /opt/openresty-lua/share/lua

# prepare custom configuration
RUN mkdir -p /etc/nginx/lua && \
    mkdir -p /etc/nginx/conf.d

COPY ./s3-proxy.lua /etc/nginx/lua
COPY ./default.conf /etc/nginx/conf.d
COPY ./default.main /etc/nginx/conf.d

# Stage 2: create distroless image
FROM gcr.io/distroless/cc-debian12

# additional libs
COPY --from=builder /lib/x86_64-linux-gnu/libcrypt.so.1 /lib/x86_64-linux-gnu/
# binary, dependencies and config
COPY --from=builder /opt/openresty-lua /usr/local
COPY --from=builder /etc/nginx /etc/nginx

# runtime config
WORKDIR /
EXPOSE 80

USER nonroot:nonroot

ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin"

ENTRYPOINT ["/usr/local/openresty/bin/openresty", "-g", "pid /tmp/nginx.pid; daemon off;"]
