#!/bin/bash
set -e

# Set default environment variables if not provided
LOGROTATE_COPIES=${LOGROTATE_COPIES:-12}
LOGS_DIRECTORIES=${LOGS_DIRECTORIES:-"/logs"}
LOGROTATE_INTERVAL=${LOGROTATE_INTERVAL:-"monthly"}
LOGROTATE_COMPRESSION=${LOGROTATE_COMPRESSION:-"compress"}
LOGROTATE_STATUSFILE=${LOGROTATE_STATUSFILE:-"/logs/logrotate.status"}
LOGROTATE_DATEFORMAT=${LOGROTATE_DATEFORMAT:-"-%Y%m%d%H%i%s"}

# Ensure the status file exists (prevents errors on first run)
if [ ! -f "$LOGROTATE_STATUSFILE" ]; then
  touch "$LOGROTATE_STATUSFILE"
  chown root:root "$LOGROTATE_STATUSFILE"  # Adjust ownership if needed for your container user
  chmod 644 "$LOGROTATE_STATUSFILE"
fi

# Dynamically generate a basic logrotate configuration file
cat <<EOF >/etc/logrotate.conf
$LOGS_DIRECTORIES/* {
  rotate $LOGROTATE_COPIES
  $LOGROTATE_COMPRESSION
  missingok
  notifempty
  create 0640 root root
  dateext
  dateformat $LOGROTATE_DATEFORMAT
  $LOGROTATE_INTERVAL
  sharedscripts
  postrotate
    # Optional: Add custom post-rotation commands, e.g., signal your app to reopen logs
    # echo "Logs rotated at $(date)" >> /var/log/rotation.log
  endscript
}
EOF

# Function to convert LOGROTATE_INTERVAL to sleep seconds
get_sleep_seconds() {
  case "$LOGROTATE_INTERVAL" in
    hourly) echo 3600 ;;   # 1 hour
    daily) echo 86400 ;;   # 24 hours
    weekly) echo 604800 ;; # 7 days
    monthly) echo 2592000 ;; # ~30 days
    *) echo "Invalid interval: $LOGROTATE_INTERVAL. Defaulting to daily." >&2; echo 86400 ;;
  esac
}

# Get the sleep duration
SLEEP_SECONDS=$(get_sleep_seconds)

# Run logrotate in an infinite loop to keep the container alive
while true; do
  echo "Running logrotate at $(date)..."
  logrotate -v -s "$LOGROTATE_STATUSFILE" /etc/logrotate.conf  # -v for verbose output to logs
  if [ $? -eq 0 ]; then
    echo "Logrotate completed successfully."
  else
    echo "Logrotate failed with exit code $?." >&2
  fi
  echo "Sleeping for $SLEEP_SECONDS seconds until next run..."
  sleep "$SLEEP_SECONDS"
done
