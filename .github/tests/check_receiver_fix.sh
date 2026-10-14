#!/usr/bin/env bash
# Checks that the IR receiver fix made it into a compiled firmware:
# the digitalRead() wrapper is linked in, and ESPHome's interrupt-safe pin
# read (used by remote_receiver) calls the wrapper instead of LibreTiny's
# original digitalRead().
#
# Usage: check_receiver_fix.sh <esphome build directory>
set -euo pipefail

build_dir="${1:?usage: $0 <esphome build directory>}"
isr_read="esphome::libretiny::ISRInternalGPIOPin::digital_read()"

nm_tool=$(find "$HOME/.platformio/packages" -type f -name 'arm-none-eabi-nm' -print -quit)
if [[ -z "$nm_tool" ]]; then
  echo "arm-none-eabi-nm not found, was the firmware compiled?" >&2
  exit 1
fi
objdump_tool="${nm_tool%nm}objdump"

while IFS= read -r elf; do
  "$nm_tool" "$elf" | grep -q ' T __wrap_digitalRead$' || continue
  echo "Wrapper found in $elf"

  isr_body=$("$objdump_tool" -d -C "$elf" | awk -v name="<$isr_read>:" 'index($0, name) {found = 1} found && /^$/ {exit} found')
  if [[ -z "$isr_body" ]]; then
    echo "$isr_read not found in $elf" >&2
    exit 1
  fi
  if grep -q '__wrap_digitalRead' <<< "$isr_body"; then
    echo "$isr_read calls __wrap_digitalRead: receiver fix is active"
    exit 0
  fi
  echo "$isr_read does not call __wrap_digitalRead:" >&2
  echo "$isr_body" >&2
  exit 1
done < <(find "$build_dir" -name '*.elf')

echo "No firmware with __wrap_digitalRead found below $build_dir" >&2
exit 1
