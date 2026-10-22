# ESPHome for the Broadlink RM4 Pro

Part of [ESPHome-Broadlink-RM4](../../README.md).

The RM4 Pro is the RM4 Mini with an additional 433 MHz radio. It uses the same
Wi-Fi chip, so infrared works with the same layers as on the
[RM4 Mini](../rm4-mini/README.md). The radio is the open part: it sits behind
its own microcontroller and nobody has published a working ESPHome setup for it
yet.

**This device is under development and only exists on the `dev` branch.**

- [Status](#status)
- [Supported hardware](#supported-hardware)
- [Pin map](#pin-map)
- [Before you flash: read the stock boot log](#before-you-flash-read-the-stock-boot-log)
- [Flashing](#flashing)
- [433 MHz RF](#433-mhz-rf)
- [Testing 433 MHz without a transmitter](#testing-433-mhz-without-a-transmitter)

## Status

| Feature | State |
|---|---|
| IR emitter and receiver | Built from the same layers as the RM4 Mini. Pins taken from phdindota's notes, not confirmed on a device by this project yet. |
| Status LED, button | Same as above. |
| 433 MHz receive | Research. The raw pin documented so far only shows noise, see [433 MHz RF](#433-mhz-rf). |
| 433 MHz transmit | Not started, the pin is unknown. |

## Supported hardware

| | |
|---|---|
| Device | Broadlink RM4 Pro |
| Main board | `RM4_PRO V2.1.6` (2021-08-26), as reported by phdindota |
| Wi-Fi module | BL3357-P with a **Realtek RTL8720CF**, 4 MB flash according to phdindota |
| RF module | BL3361-1, a separate microcontroller with a 433 MHz transceiver |
| Platform | ESPHome via [LibreTiny](https://github.com/libretiny-eu/libretiny), board `generic-rtl8720cf-2mb-992k` |

The firmware is built for the 2 MB board layout of the Mini. It fits into the
larger flash of the Pro and leaves the rest unused.

## Pin map

Source: [phdindota/broadlink-rm4pro-esphome](https://github.com/phdindota/broadlink-rm4pro-esphome).
None of these pins have been confirmed on a device by this project yet.

| Function | Pin | Used here | Notes |
|---|---|---|---|
| IR transmitter (carrier) | `PA4` | yes | same as the RM4 Mini |
| IR receiver (data) | `PA18` | yes | same as the RM4 Mini |
| Status LED | `PA7` | yes | inverted (on = low) |
| Button | `PA19` | yes | inverted, internal pull-up |
| RF data | `PA20` | only in `rf-probe.yaml` | raw output of the RF side, see below |
| Network LED / UART2 RX | `PA15` | no | phdindota lists it twice; treated as the RX line of the flashing UART, like on the Mini |
| UART2 TX | `PA16` | no | flashing UART |
| Boot mode | `PA0` | no | pull high at power-up for download mode |

## Before you flash: read the stock boot log

The pin map of the RM4 Mini comes from the boot log of its stock firmware. The
log of the RM4 Pro has the same sections, including `rf in profile`, which
should name the pins of the RF part. That is the fastest way to confirm the
table above and to learn what the RF module is connected to.

1. Wire the UART adapter as described under [Flashing](#flashing), but do
   **not** bridge the boot pin.
2. Open a serial terminal on the adapter, 115200 baud (the usual log speed of
   Realtek chips, try other rates if the output is garbled).
3. Power-cycle the RM4 Pro and save everything it prints during boot.

Please add the `irda` and `rf` sections of that log to an issue or pull
request, they settle most open questions of this page.

## Flashing

The procedure is the same as for the RM4 Mini, including the backup of the
stock firmware, see [Flashing](../rm4-mini/README.md#flashing). Differences
according to phdindota:

- The serial port is on the `WIFI DEBUG` header: adapter TX to pin 16 (RX2),
  adapter RX to pin 17 (TX2), plus GND.
- Download mode: bridge `PA0` (pin 21 of that header) to `3.3V`, then
  power-cycle the device.
- Name the backup `rm4pro-stock.bin`.

Build the firmware from [`example.yaml`](example.yaml). It pulls the device
file from the `dev` branch of this repository.

## 433 MHz RF

What is known:

- The RF part is a separate microcontroller (BL3361-1). The Wi-Fi chip talks
  to it somehow, and how is not documented.
- phdindota found a pin (`PA20`) that carries the raw RF data, but it showed
  constant noise instead of decodable pulses.
- The Broadlink protocol learns RF in two steps: it first sweeps for the
  frequency of your remote, then records the packet. That points to a tunable
  transceiver which has to be configured by the Wi-Fi chip, not to a fixed
  receiver that simply outputs data. A plain `remote_receiver` on `PA20` is
  therefore probably not enough.

The likely path to a working RF part:

1. Read the stock boot log, see above.
2. Find out how the Wi-Fi chip talks to the RF module (serial or SPI), for
   example with a logic analyzer on the stock firmware while it learns a code.
3. Re-implement that protocol, probably as an ESPHome external component.
4. Expose it on ESPHome's `radio_frequency` platform, so Home Assistant sees a
   native RF transmitter and receiver. At the time of writing ESPHome ships
   that platform without a hardware implementation.

### The RF probe

[`rf-probe.yaml`](rf-probe.yaml) is a small optional package for the research
part. It prints the pulse timings seen on the RF data pin to the log and
creates no entity in Home Assistant. Add it after the device file:

```yaml
packages:
  broadlink_rm4_pro:
    url: https://github.com/seb5594/ESPHome-Broadlink-RM4-Mini
    ref: dev
    files:
      - devices/rm4-pro/rm4-pro.yaml
      - devices/rm4-pro/rf-probe.yaml
```

Press a 433 MHz remote right next to the device and watch the log. If only
random pulses show up, you see the same noise phdindota did. If your remote
produces a repeating pattern, that is worth sharing. `pin_rf_data` can be
overridden to probe other pins.

## Testing 433 MHz without a transmitter

433 MHz is a free band, so the test equipment is cheap. Any of these works as
a signal source:

- **A fixed-code key fob** (EV1527 or PT2262 type, a few euros): the simplest
  signal there is. Ideal to see whether anything arrives at all.
- **A set of 433 MHz wireless sockets** (Intertechno, Brennenstuhl and similar):
  gives you a receiver to switch, so you can also test sending.
- **Everyday devices**: wireless doorbells, garage or gate remotes, weather
  station sensors and some alarm sensors transmit on 433.92 MHz.

For an independent view on what is on the air:

- **An RTL-SDR stick** with [rtl_433](https://github.com/merbanan/rtl_433)
  shows what a transmitter, or the RM4 Pro, really sends.
- **A second ESP32** with a cheap receiver module (RXB6, SRX882) and ESPHome's
  `remote_receiver` records the timings of anything the RM4 Pro transmits. With
  a cheap transmitter module (FS1000A) it can also act as a test signal source.

Test with the stock firmware first: learn a remote through the Home Assistant
Broadlink integration (`remote.learn_command` with `command_type: rf`). That
proves your signal source and the hardware before any ESPHome code is involved,
and it is the baseline to compare against.
