#!/bin/bash

# Set the registry directory, defaulting to /var/run/passenger-instreg if not set
REGISTRY_DIR="${PASSENGER_INSTANCE_REGISTRY_DIR:-/var/run/passenger-instreg}"

# Check if the directory exists
if [[ ! -d "$REGISTRY_DIR" ]]; then
  echo "Registry directory $REGISTRY_DIR does not exist."
  exit 1
fi

# Get a list of folders sorted by modification time (newest last)
folders=($(ls -td "$REGISTRY_DIR"/*/))

# If there is more than one folder, we skip the latest one
if [[ ${#folders[@]} -gt 1 ]]; then
  # Loop through all folders except the last (newest)
  for folder in "${folders[@]:1}"; do
    # Get the folder creation time in seconds since epoch
    folder_time=$(stat -c %Y "$folder")

    # Calculate the time difference
    time_diff=$((current_time - folder_time))

    # Skip folders created within the last 60 seconds (1 minute)
    if [[ $time_diff -lt 60 ]]; then
      echo "Skipping folder $folder, created less than a minute ago."
      continue
    fi
    # Loop through all folders except the first (newest)
    if [[ -f "$folder/watchdog.pid" ]]; then
      # Read the PID from watchdog.pid
      pid=$(cat "$folder/watchdog.pid")
      
      # Attempt to kill the process
      if kill "$pid" 2>/dev/null; then
        echo "Killed PID $pid in $folder"
      else
        echo "Failed to kill PID $pid in $folder (process may not exist)"
      fi
    else
      echo "No watchdog.pid found in $folder"
    fi
  done
elif [[ ${#folders[@]} -eq 1 ]]; then
  echo "No folders to kill processes in, only one instance found."
else
  echo "Something wrong, trying to restart."
  systemctl restart nginx
fi
