#!/bin/sh
set -e

# Set default environment variables if not set (example values)
LOGROTATE_COPIES=${LOGROTATE_COPIES:-12}
LOGS_DIRECTORIES=${LOGS_DIRECTORIES:-"/logs"}
LOGROTATE_INTERVAL=${LOGROTATE_INTERVAL:-"monthly"}
LOGROTATE_COMPRESSION=${LOGROTATE_COMPRESSION:-"compress"}
LOGROTATE_STATUSFILE=${LOGROTATE_STATUSFILE:-"/logs/logrotate.status"}
LOGROTATE_DATEFORMAT=${LOGROTATE_DATEFORMAT:-"-%Y%m%d%H%i%s"}

# Create status file if it doesn't exist
if [ ! -f "$LOGROTATE_STATUSFILE" ]; then
  touch "$LOGROTATE_STATUSFILE"
fi

# Generate a basic logrotate configuration dynamically
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
    # Example postrotate script: can be customized or left empty
    # echo "Logs rotated"
  endscript
}
EOF

# Run logrotate command with status file and config
exec logrotate -s "$LOGROTATE_STATUSFILE" /etc/logrotate.conf
