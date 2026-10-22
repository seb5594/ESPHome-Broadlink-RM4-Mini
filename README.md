# ESPHome Broadlink RM4

[![Validate](https://github.com/seb5594/ESPHome-Broadlink-RM4-Mini/actions/workflows/validate.yml/badge.svg)](https://github.com/seb5594/ESPHome-Broadlink-RM4-Mini/actions/workflows/validate.yml)
![ESPHome](https://img.shields.io/badge/ESPHome-%E2%89%A5%202026.9.0-000000?logo=esphome)
![Home Assistant](https://img.shields.io/badge/Home%20Assistant-%E2%89%A5%202026.6.0-41BDF5?logo=homeassistant)
![License](https://img.shields.io/badge/license-MIT-green)

Local, cloud-free ESPHome firmware for the Broadlink RM4 family. Flashed
devices show up in Home Assistant as native **infrared** emitters and receivers
on Home Assistant's `infrared` platform, so everything that builds on it works
right away, for example [HAIR](https://github.com/DAB-LABS/HAIR) or the LG and
Samsung infrared integrations.

## Devices

| Device | State | Branch |
|---|---|---|
| [RM4 Mini / RM4C Mini](devices/rm4-mini/README.md) | works: infrared emitter and receiver | `main`, `dev` |
| [RM4 Pro](devices/rm4-pro/README.md) | in development: infrared expected to work, 433 MHz RF is research | `dev` |

## Requirements

| What | Version | Why |
|---|---|---|
| ESPHome | **2026.9.0** or newer | First release whose `remote_transmitter` works on the RTL8720C: hardware PWM carrier ([esphome#18579](https://github.com/esphome/esphome/pull/18579)) and timer-driven, non-blocking sending ([esphome#18648](https://github.com/esphome/esphome/pull/18648)). Older releases crash the chip as soon as something is sent. Enforced by `min_version` in the config. |
| Home Assistant | **2026.6.0** or newer | First release that creates the receiver entity for ESPHome IR proxies. Sending alone works from 2026.4.0. |
| [HAIR](https://github.com/DAB-LABS/HAIR) | optional | Admin UI to capture, organize and send IR codes. Any other consumer of the `infrared` platform works too. |

For the first flash you also need:

- a USB-UART adapter with **3.3 V logic levels** (e.g. CH340, CP2102, FT232)
- a few jumper wires, ideally a soldering iron (the pads are through-holes)
- [ltchiptool](https://github.com/libretiny-eu/ltchiptool) to back up the stock
  firmware and flash ESPHome

Every later update goes over Wi-Fi.

## Getting started

1. Pick your device above and follow its page: identify the board, open the
   case, back up the stock firmware, flash.
2. Copy the `example.yaml` of your device into the ESPHome dashboard and add the
   keys from [`secrets.yaml.example`](secrets.yaml.example) to your secrets.
3. Add the device in Home Assistant, see [Home Assistant](docs/home-assistant.md).

## How it is built

The firmware is assembled from small ESPHome packages. A device file only holds
the pin map and the identity of the hardware, the rest is shared:

```text
devices/<device>/        pin map, example.yaml and the guide of one device
common/                  base (API, OTA, hotspot), controls (LED, button), IR proxy
platform/rtl8720c/       chip specifics: board, logger, the IR receiver fix
docs/                    configuration, Home Assistant and HAIR, troubleshooting
.github/                 CI: lint, build for every device, remote package check
```

A new RM4 variant needs a new folder under `devices/` and, if it brings
hardware the shared layers don't cover, a new layer next to them. More in
[ESPHome configuration](docs/configuration.md).

## Branches

- `main` is the stable state. Everything on it has been tested on a device.
- `dev` is where development happens, including devices that are not finished.
  To try it, set `ref: dev` in the package of your device config.

The `example.yaml` of a released device points to `main`. For a pinned state use
a commit hash or tag as `ref`.

## Documentation

- [ESPHome configuration](docs/configuration.md)
- [Home Assistant and HAIR](docs/home-assistant.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Changelog](CHANGELOG.md)

## Thanks

A big thank you to **phdindota** and
[phdindota/broadlink-rm4mini-esphome](https://github.com/phdindota/broadlink-rm4mini-esphome).
Without that project this one wouldn't exist: it was the first to put ESPHome
on the RM4 Mini, worked out the pin map from the stock firmware, documented how
to open and flash the device, found the cause of the silent IR receiver and
provided the photo of the board used in the RM4 Mini guide (MIT licensed). The
RM4 Pro work builds on the notes in
[phdindota/broadlink-rm4pro-esphome](https://github.com/phdindota/broadlink-rm4pro-esphome).

Thanks as well to

- [LibreTiny](https://github.com/libretiny-eu/libretiny) for bringing ESPHome
  to the RTL8720CF,
- [ESPHome](https://esphome.io/) for the RTL8720C transmitter work and the IR
  proxy,
- [DAB-LABS](https://github.com/DAB-LABS) for [HAIR](https://github.com/DAB-LABS/HAIR).

## License

[MIT](LICENSE)
