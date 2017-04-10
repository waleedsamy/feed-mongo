#!/bin/bash
set -e

aws_cred_available (){
  if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$S3_URI" ]; then
    return 1;
  fi
  return 0;
}

#  [s3_ls_file List files in $1 and region $2]
#  output:
#   2017-04-05 15:33:41      29494 what.csv.gz
s3_ls_file (){
  aws s3 ls --region $2 $1
}

# [wait_till_mongo_ready wait till mongodb is ready]
wait_till_mongo_ready() {
  until nc -z $MONGO_HOST $MONGO_PORT
  do
    sleep 1
  done
}

# [file_must_exist exit this script with status 1, if file $1 does not exist]
file_must_exist (){
  if [ ! -f "$1" ]; then
    >&2 echo "provided local file at $1 does not exist!"
    exit 1;
  fi
}

# [load_from_s3 download a csv file from s3, and import it into mongodb]
load_from_s3 (){
  s3_gz_source=/s3/data.csv.gz
  aws s3 cp --region $AWS_DEFAULT_REGION $S3_URI $s3_gz_source
  import $s3_gz_source
}

# [load_from_local import local csv file into mongodb]
load_from_local (){
  import $LOCAL_FILE
}

# [import import $1 (csv-file/gzip-csv) into mongodb ]
import (){

  csv_file=/csv/data.csv

  case "$1" in
    *.gz | *.tgz )
        echo extract file $1 '->' $csv_file
        gunzip -kfc $1 > $csv_file
        ;;
    *)
        echo cp not gzipped file $1 '->' $csv_file
        \cp -fR $1 $csv_file
        ;;
  esac

  wait_till_mongo_ready

  echo importing $csv_file into $MONGO_HOST:$MONGO_PORT

  mongoimport --host $MONGO_HOST:$MONGO_PORT \
              --db $MONGO_DB --drop \
              --collection $MONGO_COLLECTION \
              --type csv --headerline \
              --columnsHaveTypes \
              --parseGrace autoCast \
              --file $csv_file
}

# Neither aws credentials nor local csv file provided
if ! aws_cred_available && [ -z "$LOCAL_FILE" ] ; then
  >&2  echo "please provide aws credentials or local file path - check README file";
  exit 1;
# aws credentials available but not local file provided
elif aws_cred_available && [ -z "$LOCAL_FILE" ] ; then
  echo "No local file provided, that okay, gonna use aws"
  echo "AWS credentials found in env AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"

  load_from_s3
# local file provided, but no aws credentials detected
elif ! aws_cred_available && [ "$LOCAL_FILE" ] ; then
  echo "local file provided"
  echo "No aws credentials detected"

  file_must_exist $LOCAL_FILE
  load_from_local
# local file provided, and aws credentials detected
else
  echo "aws credentials and local file path provided, the bigger will be loaded"
  # the provided local file does not exist
  if [ ! -f "$LOCAL_FILE" ]; then
    load_from_s3
  else
   local_file_size=$(ls -ltS $LOCAL_FILE | awk {'print $5'} | awk 'FNR == 1 {print $1}')
   s3_file_size=$(s3_ls_file $S3_URI $AWS_DEFAULT_REGION | awk 'FNR == 1 {print $3}' | awk '{printf("%d\n",$1 + 0.5)}')

   # load date form the bigger file
   if [ "$s3_file_size" -gt "$local_file_size" ]; then
     echo s3 file \($s3_file_size\) is bigger than the local file \($local_file_size\)
     load_from_s3
   else
     echo the local file \($local_file_size\) is bigger than the s3 file \($s3_file_size\)
     load_from_local
   fi
  fi
fi
