#!/bin/bash

rm -f opt/logs/{access,error}.log
touch opt/logs/{access,error}.log
./opt/sbin/nginx
sleep 1
curl -s -o /dev/null -w "%{http_code}\n" localhost:8090
REGISTRY_DIR=./opt/passenger_temp CLEANTIME=0 ./cleanup.sh
./opt/sbin/nginx -s reload
sleep 1
curl -s -o /dev/null -w "%{http_code}\n" localhost:8090
REGISTRY_DIR=./opt/passenger_temp CLEANTIME=0 ./cleanup.sh
./opt/sbin/nginx -s reload
sleep 1
curl -s -o /dev/null -w "%{http_code}\n" localhost:8090
REGISTRY_DIR=./opt/passenger_temp CLEANTIME=0 ./cleanup.sh
sleep 1
killall nginx
