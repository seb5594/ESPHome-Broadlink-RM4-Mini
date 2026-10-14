# Changelog

## 1.0.0 - 2026-10-14

First release.

- Broadlink RM4 Mini / RM4C Mini (board `RM4_MINI-MAIN-V4.0.1`, RTL8720CF) as
  a native Home Assistant IR proxy: IR emitter and IR receiver on the
  `infrared` platform via `ir_rf_proxy`, ready for HAIR and every other
  integration built on that platform.
- Transmitter on ESPHome's own `remote_transmitter` with hardware PWM carrier
  and non-blocking sending, no custom `ir_tx.h` any more.
- Receiver fix for the RTL8720C: `digitalRead()` is wrapped at link time so
  `remote_receiver` keeps its interrupt. Based on the LibreTiny patch from
  [phdindota/broadlink-rm4mini-esphome](https://github.com/phdindota/broadlink-rm4mini-esphome).
- Hardware config as an ESPHome package; a device needs only a few lines of
  YAML (see `example.yaml`).
- Status LED, physical button, fallback hotspot with captive portal.
- Guide for opening the case, UART wiring, stock firmware backup and flashing.
- CI: yamllint, config validation and a full build against ESPHome 2026.9.0
  and the current release, plus a check in the firmware binary that the
  receiver fix is active.

Requires ESPHome 2026.9.0 and Home Assistant 2026.6.0 or newer.
