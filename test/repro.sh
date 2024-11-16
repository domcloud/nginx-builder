#!/bin/bash

killall nginx
rm -f opt/logs/{access,error,pid,passenger}.log
touch opt/logs/{access,error,pid,passenger}.log
./opt/sbin/nginx

for run in {1..50}; do
    sleep 0.1
    echo "F"
    curl -s -o /dev/null -w "%{http_code}\n" localhost:8090 --max-time 1
    echo "E"
    ps -eo pid,cmd:40,exe --forest | grep nginx-builder >> opt/logs/pid.log
    echo "D"
    echo "$(pgrep nginx | wc -l)---" >> opt/logs/pid.log
    echo "C"
    REGISTRY_DIR=./opt/passenger_temp ./cleanup.sh
    echo "B"
    ./opt/sbin/nginx -s reload
    echo "A"
done

ps -eo pid,cmd:40,exe --forest | grep nginx-builder >> opt/logs/pid.log
killall nginx
REGISTRY_DIR=./opt/passenger_temp ./cleanup.sh
