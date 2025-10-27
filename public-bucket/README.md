# Nginx + S3

## Getting startet

Just run the following and everything should be up and running. You may want
to change the credentials for Minio set in `.env`.
```shell
docker compose up -d
```

Open a browser and verify that [Minio](http://localhost:9080) (credentials are
set in the file `.env`) and [Nginx](http://localhost:8080) are ready. 
The latter should show the sample website given by the `index.html`.

## Minio CLI

Assuming Nginx and Minio container are already running, started via docker
compose as shown above. However the following tasks are alreay executed by
docker compose.

Create minio config
```shell
docker run --rm -it --network host -v ./mc_data:/root/.mc minio/mc alias set local http://localhost:9081 admin minio-admin-password
docker run --rm -it --network host -v ./mc_data:/root/.mc minio/mc ls local
```

Create bucket `website`
```shell
docker run --rm -it --network host -v ./mc_data:/root/.mc minio/mc mb local/website
```

Make bucket public
```shell
docker run --rm -it --network host -v ./mc_data:/root/.mc minio/mc anonymous set public local/website
```

Upload index.html
```shell
docker run --rm -it --network host -v ./mc_data:/root/.mc -v "./index.html:/tmp/index.html" minio/mc put /tmp/index.html local/website
```