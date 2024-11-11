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
    # Loop through all folders except the first (newest)
    if [[ -f "$folder/watchdog.pid" ]]; then
      # Read the PID from watchdog.pid
      pid=$(cat "$folder/watchdog.pid")
      
      # Attempt to kill the process
      if kill "$pid" 2>/dev/null; then
        echo "Killed PID $pid in $folder"
      elif ! kill -0 "$pid" 2>/dev/null; then
        # Check if the process still exists
        echo "Process $pid not found, deleting folder $folder"
        rm -rf "$folder"
      else
        echo "Failed to kill PID $pid in $folder (process may still be running)"
      fi
    else
      echo "No watchdog.pid found in $folder"
    fi
  done
elif [[ ${#folders[@]} -gt 0 ]]; then
  echo "No folders to kill processes in, only one PID found which ${folders[0]}"
else
  echo "Something wrong, trying to restart."
  systemctl restart nginx
fi
