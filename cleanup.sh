#!/bin/bash

# Set the registry directory, defaulting to /var/run/passenger-instreg if not set
REGISTRY_DIR="${REGISTRY_DIR:-/var/run/passenger-instreg}"

CLEANTIME="${CLEANTIME:-60}"

# Check if the directory exists
if [[ ! -d "$REGISTRY_DIR" ]]; then
  echo "Registry directory $REGISTRY_DIR does not exist."
  exit 1
fi

# Get a list of folders sorted by modification time (newest last)
folders=($(ls -td "$REGISTRY_DIR"/*/))
# folders=($(find $REGISTRY_DIR -mindepth 1 -maxdepth 1 -type d ! -lname '*' -exec stat --format='%Y %n' {} + | sort -n | awk '{print $2}'))

current_time=$(date +%s)

# If there is more than one folder, we skip the latest one
if [[ ${#folders[@]} -gt 1 ]]; then
  echo "Alive PID is ${folders[0]}"
  # Loop through all folders except the last (newest)
  for folder in "${folders[@]:1}"; do
    # Get the folder creation time in seconds since epoch
    folder_time=$(stat -c %Y "$folder")

    # Calculate the time difference
    time_diff=$((current_time - folder_time))

    # Skip folders created within the last 60 seconds (1 minute)
    if [[ $time_diff -lt $CLEANTIME ]]; then
      echo "Skipping folder $folder, created less than $CLEANTIME seconds ago."
      continue
    fi
    if [[ ! -f "$folder/watchdog.pid" ]]; then
      echo "No watchdog.pid found in $folder"
    fi
    if [[ ! -f "$folder/web_server_info/child_process.pid" ]]; then
      echo "No child_process.pid found in $folder"
    fi

    # Read the PID from watchdog.pid
    nid=$(cat "$folder/web_server_info/child_process.pid")
    pid=$(cat "$folder/watchdog.pid")
    if kill -0 "$nid" 2>/dev/null; then
      # Check if the process still exists
      echo "Worker $pid still running so skip $folder"
    elif ! kill -0 "$pid" 2>/dev/null; then
      # Check if the process still exists
      echo "Process $pid not found, deleting folder $folder"
      rm -rf "$folder"
    else
      kill $pid
      tail --pid=$pid -f /dev/null
      echo "Killed PID $pid in $folder"
      rm -rf "$folder"
    fi
  done
elif [[ ${#folders[@]} -gt 0 ]]; then
  echo "No folders to kill processes in, only one PID found which ${folders[0]}"
else
  echo "Something wrong, trying to restart."
  systemctl restart nginx
fi
