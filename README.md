#### feed-mongo
> Container responsible for loading csv data from local/S3 into mongodb

[![Docker Hub](https://img.shields.io/badge/docker-ready-blue.svg)](https://registry.hub.docker.com/u/waleedsamy/feed-mongo/)


#### how does it work?
  * load gzip-csv or csv file into mongodb. Next, I'll use word `csv file` to mean the z.csv.gz or z.csv
  * csv file can be loaded using env `LOCAL_FILE` which point to the file path inside the docker container (mount the file by docker volumes)
  * csv file can be loaded from s3 by providing env `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `S3_URI`
  * if both local file and s3 file provided, the bigger file will be loaded
  * if both files provided, and the local file is the biggest, s3 file will not be downloaded
  * if neither aws nor local file passed, the container will exit with error

##### Build
```bash
  docker build -t feed-mongo .
```

#### Run
```bash
  $ docker run -P --name mongo -d mongo
  $ docker run \
      -d --rm \
      --link mongo \
      --name feed-mongo \
      -e AWS_ACCESS_KEY_ID=*************** \
      -e AWS_SECRET_ACCESS_KEY=****************************************** \
      -e S3_URI=s3://bucket/a/b/c/d/file.csv.gz \
      -e LOCAL_FILE=/data/file.csv.gz \
      waleedsamy/feed-mongo
```

#### Customized container env variables:
 * AWS_ACCESS_KEY_ID aws access key id **required**
 * AWS_SECRET_ACCESS_KEY aws secret access key **required**
 * S3_URI s3 file to download **required** i.e. `s3://bucket/a/b/c/d/file.csv.gz`
 * AWS_DEFAULT_REGION s3 bucket region _optional_ default `eu-central-1`
 * LOCAL_FILE load a local csv file **required** i.e. `/data/file.csv.gz`
 * MONGO_HOST mongodb host _optional_ default `mongo`
 * MONGO_PORT mongodb port _optional_ default `27017`
 * MONGO_DB mongodb name _optional_ default `local`
 * MONGO_COLLECTION mongodb collection to use _optional_ default `hotels`
