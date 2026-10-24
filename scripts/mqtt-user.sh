#!/bin/sh
set -eu

usage() {
    echo "Usage: $0 USERNAME [docker compose options, e.g. -p iotstack]"
}

if [ "$#" -eq 1 ] && { [ "$1" = '--help' ] || [ "$1" = '-h' ]; }; then
    usage
    exit 0
fi
if [ "$#" -lt 1 ]; then
    usage >&2
    exit 1
fi
username=$1
shift
case "$username" in
    ''|-*|*:*|*'
'*|*''*)
        echo 'Invalid MQTT username: use a nonempty name without colons or line breaks, not starting with a dash.' >&2
        exit 1
        ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$script_dir/.."

compose() {
    if docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    else
        docker-compose "$@"
    fi
}

# A one-off container also works before the broker has been started.
# The password is entered directly into mosquitto_passwd, never as an argument.
compose "$@" run --rm --no-deps --user 0 --entrypoint sh mosquitto -eu -c '
    password_file=/mosquitto/config/passwd
    umask 077
    if [ -e "$password_file" ]; then
        mosquitto_passwd "$password_file" "$1"
    else
        mosquitto_passwd -c "$password_file" "$1"
    fi
    chown mosquitto:mosquitto "$password_file"
    chmod 640 "$password_file"
' sh "$username"

if [ -n "$(compose "$@" ps --status running -q mosquitto)" ]; then
    compose "$@" kill -s HUP mosquitto
    echo 'MQTT user saved; Mosquitto reloaded.'
else
    echo 'MQTT user saved. Start Mosquitto with docker compose up -d mosquitto.'
fi
