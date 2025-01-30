#!/bin/bash

# Set the registry directory, defaulting to /var/run/passenger-instreg if not set
REGISTRY_DIR="${REGISTRY_DIR:-/var/run/passenger-instreg}"

# Check if the directory exists
if [[ ! -d "$REGISTRY_DIR" ]]; then
  echo "Registry directory $REGISTRY_DIR does not exist."
  exit 1
fi

# Get a list of folders sorted by modification time (newest last)
folders=($(ls -td "$REGISTRY_DIR"/*/))

# If there is more than one folder, we skip the latest one
if [[ ${#folders[@]} -gt 1 ]]; then
  echo "Alive PID is ${folders[0]}"
  # Loop through all folders except the last (newest)
  for folder in "${folders[@]:1}"; do

    if [[ ! -f "$folder/watchdog.pid" ]]; then
      echo "No watchdog.pid found in $folder"
      continue
    fi
    if [[ ! -f "$folder/web_server_info/child_processes.pid" ]]; then
      echo "No child_processes.pid found in $folder"
      continue
    fi

    nids=($(grep -v '^$' "$folder/web_server_info/child_processes.pid"))
    pid=$(cat "$folder/watchdog.pid")

    # Check if any of the PIDs exist
    for nid in "${nids[@]}"; do
      if [[ -n "$nid" ]] && kill -0 "$nid" 2>/dev/null; then
        # If any PID exists, skip the folder
        echo "Worker $pid still running so skip $folder"
        continue 2  # Skip further processing for this folder
      fi
    done

    if ! kill -0 "$pid" 2>/dev/null; then
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
  folder=${folders[0]}
  if [[ ! -f "$folder/watchdog.pid" ]]; then
    echo "No watchdog.pid found in $folder"
  else
    pid=$(cat "$folder/watchdog.pid")
    if ! kill -0 "$pid" 2>/dev/null; then
      # Check if the process still exists
      echo "The only process $pid is not found, deleting folder $folder and restarting NGINX"
      rm -rf "$folder"
      systemctl restart nginx
    else
      echo "No folders to kill processes in, only one PID found which ${folders[0]}"
    fi
  fi
else
  echo "Something wrong, trying to restart."
  systemctl restart nginx
fi
