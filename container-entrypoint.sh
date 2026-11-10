#!/bin/bash

# Set default environment variables if not provided
LOGROTATE_COPIES=${LOGROTATE_COPIES:-12}
LOGS_DIRECTORIES=${LOGS_DIRECTORIES:-"/logs"}
LOGROTATE_INTERVAL=${LOGROTATE_INTERVAL:-"monthly"}
LOGROTATE_COMPRESSION=${LOGROTATE_COMPRESSION:-"compress"}
LOGROTATE_STATUSFILE=${LOGROTATE_STATUSFILE:-"/logs/logrotate.status"}
LOGROTATE_DATEFORMAT=${LOGROTATE_DATEFORMAT:-"-%Y%m%d%H%M%S"}
# how often logrotate checks the files, it rotates them only when LOGROTATE_INTERVAL has passed
LOGROTATE_CHECK_SECONDS=${LOGROTATE_CHECK_SECONDS:-3600}

CONFIG_FILE=/etc/logrotate.conf

# Ensure the status file exists (prevents errors on first run)
if [ ! -f "$LOGROTATE_STATUSFILE" ]; then
  mkdir -p "$(dirname "$LOGROTATE_STATUSFILE")"
  touch "$LOGROTATE_STATUSFILE"
  chmod 644 "$LOGROTATE_STATUSFILE"
fi

# Lists every log file below LOGS_DIRECTORIES (space separated, searched recursively), without the
# status file and files rotated before (<name><dateext>, optionally compressed)
find_log_files() {
  local DIRECTORY
  for DIRECTORY in $LOGS_DIRECTORIES; do
    [ -d "$DIRECTORY" ] || continue
    find "$DIRECTORY" -type f \
      ! -path "$LOGROTATE_STATUSFILE" \
      ! -name '*.gz' ! -name '*.bz2' ! -name '*.xz' ! -name '*.zst' \
      ! -regex '.*-[0-9]\{8,\}$'
  done
}

# Writes the logrotate config for the files found right now, so files created later are picked up
# by the next run. copytruncate keeps the files in place: the processes writing them run in other
# containers and can't be signalled to reopen their logs.
write_config() {
  local FILE
  {
    while IFS= read -r FILE; do
      printf '"%s"\n' "$FILE"
    done
    cat <<EOF
{
  rotate $LOGROTATE_COPIES
  $LOGROTATE_COMPRESSION
  missingok
  notifempty
  copytruncate
  dateext
  dateformat $LOGROTATE_DATEFORMAT
  $LOGROTATE_INTERVAL
  su root root
}
EOF
  } > "$CONFIG_FILE"
}

# Run logrotate in an infinite loop to keep the container alive
while true; do
  FILES=$(find_log_files)
  if [ -n "$FILES" ]; then
    echo "Running logrotate at $(date)..."
    write_config <<< "$FILES"
    logrotate -v -s "$LOGROTATE_STATUSFILE" "$CONFIG_FILE"
    EXIT_CODE=$?
    if [ "$EXIT_CODE" -eq 0 ]; then
      echo "Logrotate completed successfully."
    else
      echo "Logrotate failed with exit code $EXIT_CODE." >&2
    fi
  else
    echo "No log files found in $LOGS_DIRECTORIES at $(date)."
  fi
  sleep "$LOGROTATE_CHECK_SECONDS"
done
