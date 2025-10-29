# S3 Private Bucket

## About

This project shows how to serve a static website from a private S3 bucket.
It utilizes OpenResty with a custom LUA script to generate proper request
to authenticate against the MINIO S3 storage.

## Getting startet

Just run the following and everything should be up and running. You may want
to change the credentials for Minio set in `.env`.

```shell
# create nginx cache folder
mkdir nginx_cache
# give it to nonroot (id: 65532)
chown 65532:65532 nginx_cache
# start everything else
docker compose up -d
```

Open a browser and verify that [Minio](http://localhost:9010) (credentials are
set in the file `.env`) and [Nginx](http://localhost:8081) are ready. 
The latter should show the sample website given by the `index.html`.

## Lessons Learned

### OpenResty/Nginx and ENV

Some configuration variables, mostly credentials, are passed via environment
variables to OpenResty/Nginx and subsequently to LUA. However, Nginx does not
allow to pass environment variables by default, hence the `default.main`.

### Distroless and nonroot

Using a distroless image and an unpriviledged user, i.e. nonroot, comes with
some challenges especially when dealing with permissions. However, the tag
`:debug` for any distroless image comes in very handy to help resolve any such
issues.

### LUA Script

The `s3-proxy.lua` script was conceived with help from A.I., but needed some
more work. Hence, there might be room for further improvements.