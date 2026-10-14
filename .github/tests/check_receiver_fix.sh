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

# Messages also show up as annotations when running in GitHub Actions.
fail() {
  echo "::error::$1"
  exit 1
}

nm_tool=$(find "$HOME/.platformio/packages" -type f -name 'arm-none-eabi-nm' -print -quit)
[[ -n "$nm_tool" ]] || fail "arm-none-eabi-nm not found, was the firmware compiled?"
objdump_tool="${nm_tool%nm}objdump"

mapfile -t elf_files < <(find "$build_dir" -name '*.elf')
[[ ${#elf_files[@]} -gt 0 ]] || fail "No ELF file found below $build_dir"

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

for elf in "${elf_files[@]}"; do
  # Full listings go to files first: grep -q stops reading early, which
  # would make the producing tool fail under pipefail.
  "$nm_tool" "$elf" > "$work_dir/symbols"
  grep -q ' T __wrap_digitalRead$' "$work_dir/symbols" || continue
  echo "Wrapper linked into $elf"

  "$objdump_tool" -d -C "$elf" > "$work_dir/disassembly"
  awk -v name="<$isr_read>:" 'index($0, name) {found = 1} found && /^$/ {exit} found' \
    "$work_dir/disassembly" > "$work_dir/isr_read"

  [[ -s "$work_dir/isr_read" ]] || fail "$isr_read not found in $elf"
  if grep -q '__wrap_digitalRead' "$work_dir/isr_read"; then
    echo "::notice::$isr_read calls __wrap_digitalRead, the receiver fix is active"
    exit 0
  fi
  cat "$work_dir/isr_read"
  fail "$isr_read does not call __wrap_digitalRead"
done

fail "__wrap_digitalRead is not linked into any of: ${elf_files[*]}"
