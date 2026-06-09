#!/bin/bash
set -euo pipefail

# You can use following Arguments or combinations of them:
#   --tail 500 - last 500 lines of logs for each container
#   --since 1h - all logs since 1 hour
#   --until 5m - Show logs before a timestamp or relative (e.g. 42m for 42 minutes)
# Please refer to https://docs.docker.com/reference/cli/docker/container/logs/#options

if [[ " $* " == *" --all "* ]]; then
    args=()   # no tail/since/until restrictions
elif [ "$#" -eq 0 ]; then
    # Default argument
    args=(--tail 500)
else
    args=("$@")
fi

TEMP_FILE="/tmp/docker_logs.tmp"
LIMIT_MB=20
LIMIT_BYTES=$((LIMIT_MB * 1024 * 1024))

echo "We will collect logs now with following arguments: ${args[*]}"

# Add timestamp when logs were collected, overwrite if file exist
echo -e "$(date -Ins)\n\n######\n" > "$TEMP_FILE"
# Add Information about current version and containers
echo "$(docker ps -a)" >> "$TEMP_FILE"
echo -e "\n######\n" >> "$TEMP_FILE"

while IFS= read -r container; do
    docker logs "${args[@]}" --timestamps "$container" 2>&1 |
    sed "s/^/[$container] /"
done < <(docker ps -a --format '{{.Names}}') >> "$TEMP_FILE"

FILE_SIZE=$(stat -c%s "$TEMP_FILE" 2>/dev/null || stat -f%z "$TEMP_FILE")

if [ "$FILE_SIZE" -lt "$LIMIT_BYTES" ]; then

    curl --retry 3 --retry-delay 5 "https://pastebin.hin-infra.ch/" --data-binary "@$TEMP_FILE"

    echo -e "\nPlease provide this URL to support, all logs are saved here."

else
    echo -e "Log file is too big to be uploaded, please try to reduce it by adding additional arguments like\n '--since 1h' all logs since 1 hour, or\n '--tail 500' last 500 lines of logs for each container"
    exit 1
fi

# Cleanup after execution
rm "$TEMP_FILE"

exit 0