#!/bin/bash

# URL of the website to monitor
URL="https://sgp.domcloud.co/ssh/"  # Replace with the website you want to monitor

# Log file to store the 502 error duration
LOG_FILE="502_error_log.txt"

# Variable to track whether a 502 error has occurred
in_502_error=false
error_start_time=""

# Function to get the HTTP status code
get_status_code() {
  curl -s -o /dev/null -w "%{http_code}" "$URL"
}

# Function to get the current time in milliseconds
current_time_ms() {
  echo $(date +%s%3N)
}

# Function to log the 502 error duration with millisecond precision
log_502_error_duration() {
  local start_time=$1
  local end_time=$(current_time_ms)
  local duration=$((end_time - start_time))

  echo "$(date) - 502 error lasted for $duration milliseconds" >> "$LOG_FILE"
}

# Main loop to monitor the website
while true; do
  status_code=$(get_status_code)
  if [[ "$status_code" -eq 502 ]]; then
    # If we encounter a 502 error, track the start time
    if [ "$in_502_error" = false ]; then
      in_502_error=true
      error_start_time=$(current_time_ms)
      echo "$(date) - 502 error started" >> "$LOG_FILE"
    fi
  else
    # If the 502 error is over, calculate and log the duration
    if [ "$in_502_error" = true ]; then
      in_502_error=false
      log_502_error_duration "$error_start_time"
    fi
  fi

  # Check the website every 1 second (you can adjust this interval)
done
