#!/bin/bash

killall nginx
rm -f opt/logs/{access,error,pid}.log
touch opt/logs/{access,error,pid}.log
./opt/sbin/nginx

for run in {1..50}; do
    sleep 1
    echo "F"
    curl -s -o /dev/null -w "%{http_code}\n" localhost:8090 --max-time 1
    echo "E"
    ps -eo pid,cmd:40,exe --forest | grep nginx-builder >> opt/logs/pid.log
    echo "D"
    echo "$(pgrep nginx | wc -l)---" >> opt/logs/pid.log
    echo "C"
    REGISTRY_DIR=./opt/passenger_temp CLEANTIME=30 ./cleanup.sh
    echo "B"
    ./opt/sbin/nginx -s reload
    echo "A"
done

REGISTRY_DIR=./opt/passenger_temp CLEANTIME=0 ./cleanup.sh
ps -eo pid,cmd:40,exe --forest | grep nginx-builder >> opt/logs/pid.log
killall nginx
