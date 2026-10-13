#!/bin/sh
set -eu

if [ -n "${SIMULATOR_DEVICE_KEY:-}" ]; then
  (
    while true; do
      mosquitto_pub -h mosquitto -t "devices/$SIMULATOR_DEVICE_KEY/readings" \
        -m '{"temperature":25,"humidity":60,"ph":6.5,"tds":500,"waterLevel":70,"lux":400}'
      sleep 10
    done
  ) &
fi

while true; do
  mosquitto_sub -h mosquitto -t 'devices/+/commands/pump' -F '%t %p' |
    while IFS=' ' read -r topic payload; do
      device_key=${topic#devices/}
      device_key=${device_key%/commands/pump}
      command_id=$(printf '%s' "$payload" | sed -n 's/.*"commandId":"\([^"]*\)".*/\1/p')
      is_on=$(printf '%s' "$payload" | sed -n 's/.*"isOn":\(true\|false\).*/\1/p')
      duration=$(printf '%s' "$payload" | sed -n 's/.*"durationSeconds":\([0-9]*\).*/\1/p')

      [ -n "$command_id" ] && [ -n "$is_on" ] || continue
      mosquitto_pub -h mosquitto -t "devices/$device_key/pump-status" \
        -m "{\"commandId\":\"$command_id\",\"isOn\":$is_on}"

      case "$is_on:$duration" in
        true:[0-9]*)
          (sleep "$duration"; mosquitto_pub -h mosquitto -t "devices/$device_key/pump-status" -m '{"isOn":false}') &
          ;;
      esac
    done
  sleep 1
done
