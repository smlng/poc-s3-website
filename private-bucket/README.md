# S3 Private Bucket

## About

This project shows how to serve a static website from a private S3 bucket.
It utilizes OpenResty with a custom LUA script to generate proper request
to authenticate against the MINIO S3 storage.

## Getting startet

Just run the following and everything should be up and running. You may want
to change the credentials for Minio set in `.env`.
```shell
docker compose up -d
```

Open a browser and verify that [Minio](http://localhost:9090) (credentials are
set in the file `.env`) and [Nginx](http://localhost:8090) are ready. 
The latter should show the sample website given by the `index.html`.

## Lessons Learned

### OpenResty/Nginx and ENV

Some configuration variables, mostly credentials, are passed via environment
variables to OpenResty/Nginx and subsequently to LUA. However, Nginx does not
allow to pass environment variables by default, hence the `default.main`.

### LUA Script

The `s3-proxy.lua` script was conceived with help from A.I. However, that is 
why it also contains lots of debug output - because it required a lot of 
refinement to get it working. 