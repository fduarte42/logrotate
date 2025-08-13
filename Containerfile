# Use a multi-platform compatible base image like Alpine Linux (which supports amd64 and arm64)
FROM alpine:latest

# Set environment variables (compatible with blacklabelops/logrotate)
ENV LOGROTATE_COPIES=12
ENV LOGS_DIRECTORIES="/logs"
ENV LOGROTATE_INTERVAL=monthly
ENV LOGROTATE_COMPRESSION=compress
ENV LOGROTATE_STATUSFILE=/logs/logrotate.status
ENV LOGROTATE_DATEFORMAT="-%Y%m%d%H%i%s"

# Install logrotate and bash, curl, or any required tools
RUN apk add --no-cache logrotate bash curl

COPY container-entrypoint.sh /container-entrypoint.sh
RUN chmod +x /container-entrypoint.sh

# Define volumes and working directory if applicable
VOLUME ["/logs"]
WORKDIR /

# Define the entrypoint or CMD based on the original image behavior
ENTRYPOINT ["container-entrypoint.sh"]
