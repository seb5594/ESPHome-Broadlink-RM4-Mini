# ESPHome for the Broadlink RM4 Mini / RM4C Mini

[![Validate](https://github.com/seb5594/ESPHome-Broadlink-RM4-Mini/actions/workflows/validate.yml/badge.svg)](https://github.com/seb5594/ESPHome-Broadlink-RM4-Mini/actions/workflows/validate.yml)
![ESPHome](https://img.shields.io/badge/ESPHome-%E2%89%A5%202026.9.0-000000?logo=esphome)
![Home Assistant](https://img.shields.io/badge/Home%20Assistant-%E2%89%A5%202026.6.0-41BDF5?logo=homeassistant)
![License](https://img.shields.io/badge/license-MIT-green)

Local, cloud-free firmware for the Broadlink RM4 Mini and RM4C Mini. After
flashing, the little IR blaster shows up in Home Assistant as an **infrared
emitter** and an **infrared receiver** on Home Assistant's native `infrared`
platform. Everything that builds on that platform can use it right away, for
example [HAIR](https://github.com/DAB-LABS/HAIR) or the LG and Samsung
infrared integrations.

This project stands on the groundwork of
[phdindota/broadlink-rm4mini-esphome](https://github.com/phdindota/broadlink-rm4mini-esphome),
the first ESPHome port for the RM4 Mini. Thank you, see [Thanks](#thanks).

- [Features](#features)
- [Requirements](#requirements)
- [Supported hardware](#supported-hardware)
- [Pin map](#pin-map)
- [Flashing](#flashing)
- [ESPHome configuration](#esphome-configuration)
- [Home Assistant](#home-assistant)
- [Using it with HAIR](#using-it-with-hair)
- [Troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)
- [Changelog](CHANGELOG.md)
- [Thanks](#thanks)

## Features

- Send IR codes with ESPHome's own `remote_transmitter` (hardware PWM
  carrier, non-blocking, so Wi-Fi keeps running while long codes go out)
- Receive IR codes from any remote with `remote_receiver`, including a small
  fix that makes interrupt-driven pins work on this chip
  ([details](#the-receiver-fix))
- Both exposed to Home Assistant as native infrared entities through
  `ir_rf_proxy`, no custom code or lambdas
- Status LED and the physical button
- OTA updates after the first flash, the case stays closed from then on
- One small device file per RM4, all hardware settings come from this
  repository as an ESPHome package

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

## Supported hardware

| | |
|---|---|
| Devices | Broadlink RM4 Mini, Broadlink RM4C Mini |
| Main board | `RM4_MINI-MAIN-V4.0.1` (printed on the back of the PCB) |
| Wi-Fi module | BL3357-P with a **Realtek RTL8720CF** (ARM Cortex-M33, 100 MHz, 2 MB flash) |
| Platform | ESPHome via [LibreTiny](https://github.com/libretiny-eu/libretiny), board `generic-rtl8720cf-2mb-992k` |

Broadlink has changed the internals over the years. Check the board marking
and the module before you order a UART adapter: other chips need a different
firmware. Looking for the RM4 Pro (same chip, plus 433 MHz RF)? See
[phdindota/broadlink-rm4pro-esphome](https://github.com/phdindota/broadlink-rm4pro-esphome).

## Pin map

Taken from the boot log of the stock firmware, as documented in
[phdindota/broadlink-rm4mini-esphome](https://github.com/phdindota/broadlink-rm4mini-esphome):

| Function | Pin | Used here | Notes |
|---|---|---|---|
| IR transmitter (carrier) | `PA4` | yes | `remote_transmitter`, 38 kHz, 50 % duty |
| IR receiver (data) | `PA18` | yes | `remote_receiver` |
| Status LED | `PA7` | yes | inverted (on = low) |
| Button | `PA19` | yes | inverted, internal pull-up |
| Network button | `PA15` | no | listed by the stock firmware; it is also the RX line of the flashing UART (UART2) |
| Temperature/humidity (SHT30) | soft I²C | no | the stock firmware has support enabled, the pins are still unknown |

<details>
<summary>Relevant part of the stock boot log</summary>

```text
[APP]==== rmparam in profile ====
[APP]app_network_pin 15
[APP]app_keypad_pin  19
[APP]th_support 1
[APP]energy_support 0

[APP]==== irda in profile ====
[APP]is_support 1
[APP]capin_work_level 0
[APP]carrier_pin 4
[APP]data_pin 18
[APP]data_gpt 8
[APP]carrier_gpt 1
[APP]carrier_gpt_channel 4
[APP]led_pin 7

[APP]==== rf in profile ====
[APP]is_support 0
```

</details>

Test points on the back of the board: `IOA0`, `IOA13`, `3.3V`, `U2-TX`,
`U2-RX`, `GND` (in one row along the edge) plus `5V`, `T4` and `T8`.

## Flashing

The first flash needs the serial port on the board. Every later update goes
over Wi-Fi.

### 1. Open the case

Peel off the rubber pad on the bottom of the device. The screws are hidden
underneath. Remove them and separate the two halves of the case. Keep the pad
to put it back afterwards.

### 2. Connect the UART adapter

<p align="center">
  <img src="docs/images/pcb-back.jpg" alt="Back of the RM4_MINI-MAIN-V4.0.1 board with the test points IOA0, IOA13, 3.3V, U2-TX, U2-RX and GND along the right edge" width="420">
</p>

The six test points along the edge of the board are plated through-holes.
Solder short wires to `U2-TX`, `U2-RX` and `GND`, or hold pin headers or pogo
pins in place if you don't want to solder.

<p align="center">
  <img src="docs/images/uart-wiring.svg" alt="Wiring: U2-TX to adapter RX, U2-RX to adapter TX, GND to GND, and a bridge from IOA0 to 3.3V while flashing" width="760">
</p>

| UART adapter | Board pad |
|---|---|
| GND | `GND` |
| TX | `U2-RX` |
| RX | `U2-TX` |
| 3.3V / VCC | **leave unconnected** |

Power the RM4 from its own USB cable. The adapter's 3.3 V output is usually
too weak for the Wi-Fi module and causes failed reads and writes.

### 3. Enter download mode

1. Bridge `IOA0` to `3.3V` with a short wire. The RTL8720C enters download
   mode when this pin is pulled **high** at power-up (not to GND like an
   ESP8266).
2. Make sure `IOA13` is not connected to GND.
3. Unplug and replug the USB power of the RM4.

### 4. Back up the stock firmware

Install ltchiptool (`pip install ltchiptool`, or the
[Windows GUI](https://github.com/libretiny-eu/ltchiptool/releases/latest)) and
read the complete flash:

```bash
ltchiptool flash read -d /dev/ttyUSB0 rtl8720c rm4mini-stock.bin
```

On Windows the port is called `COM3` or similar instead of `/dev/ttyUSB0`.
Keep this file. It is the only way back to the Broadlink firmware.

### 5. Build the firmware

**ESPHome dashboard (Home Assistant app)**

1. Create a new device with **+ New device**. The board type you pick in the
   wizard doesn't matter, the config gets replaced in the next step.
2. Open the new config with **Edit**, replace everything with the content of
   [`example.yaml`](example.yaml) and adjust the names at the top.
3. Add the keys from [`secrets.yaml.example`](secrets.yaml.example) to your
   secrets (**Secrets** in the top right corner of the dashboard).
4. **Install** → **Manual download** → **UF2 package (recommended)**.

**ESPHome command line**

```bash
git clone https://github.com/seb5594/ESPHome-Broadlink-RM4-Mini.git
cd ESPHome-Broadlink-RM4-Mini
cp secrets.yaml.example secrets.yaml   # fill in your values
cp example.yaml my-rm4.yaml            # adjust name and friendly_name
esphome compile my-rm4.yaml
```

The image ends up as `.esphome/build/<name>/.pioenvs/<name>/firmware.uf2`.

### 6. Flash

With `IOA0` still bridged to `3.3V`, power-cycle the RM4 once more and write
the UF2 file:

```bash
ltchiptool flash write -d /dev/ttyUSB0 broadlink-rm4c-mini.uf2
```

ltchiptool detects the file type and writes bootloader, partition table and
firmware to the right offsets. The full image
`image_flash_is.0x000000.bin` from the same build folder works as well.

### 7. First boot

Remove the bridge between `IOA0` and `3.3V`, disconnect the UART adapter and
power-cycle the RM4. It connects to your Wi-Fi and Home Assistant discovers it
within a minute. Close the case.

From now on, **Install** → **Wirelessly** in the dashboard (or
`esphome run my-rm4.yaml`) updates the device over the air.

To go back to the Broadlink firmware, repeat steps 2, 3 and 6 with
`rm4mini-stock.bin`. ltchiptool recognizes its own dumps.

## ESPHome configuration

The configuration is split in two parts:

| File | Purpose |
|---|---|
| [`broadlink-rm4-mini.yaml`](broadlink-rm4-mini.yaml) | Everything that belongs to the hardware. Used as a package and never edited by you. |
| [`src/rtl8720c_irq_read.c`](src/rtl8720c_irq_read.c) | The receiver fix, pulled in by the package. See [The receiver fix](#the-receiver-fix). |
| [`example.yaml`](example.yaml) | Your device: name, Wi-Fi, API key, hotspot password. Pulls in the package straight from GitHub. |

That keeps your own file at a few lines, and fixes in this repository reach
your device with the next build. `refresh: 1d` makes ESPHome check for a new
version once a day. If you want to stay on a fixed state, replace `ref: main`
with a commit hash or tag.

### `broadlink-rm4-mini.yaml` section by section

#### `substitutions`

```yaml
substitutions:
  name: broadlink-rm4-mini
  friendly_name: Broadlink RM4 Mini
  ir_receiver_idle: 25ms
```

Defaults that your own config overrides. `name` becomes the hostname and the
base of all entity IDs, `friendly_name` is what Home Assistant shows.
`ir_receiver_idle` is explained in the receiver section below.

#### `esphome`

```yaml
esphome:
  name: ${name}
  friendly_name: ${friendly_name}
  min_version: 2026.9.0
  project:
    name: seb5594.broadlink-rm4-mini
    version: "1.0.0"
  build_flags:
    - -Wl,--wrap=digitalRead
  includes:
    - src/rtl8720c_irq_read.c
```

`min_version` stops the build on ESPHome releases older than 2026.9.0, the
ones whose transmitter crashes this chip. `project` shows up in the device
info in Home Assistant, so you can see which version of this config runs on
the device. `build_flags` and `includes` add the receiver fix described in the
next section. The path is resolved next to the package file, so this also works
when the package comes straight from GitHub.

#### The receiver fix

Without help, the IR receiver on the RTL8720C stays silent. ESPHome's
`remote_receiver` attaches an interrupt to the receiver pin and reads the pin
level inside that interrupt with `digitalRead()`. LibreTiny, however, removes
the plain GPIO mode of a pin as soon as an interrupt is attached, because the
RTL8720C can't use both at once. The next `digitalRead()` call sets the pin up
as a GPIO input again and frees the interrupt on the way, so the receiver sees
the first edge of a code and then nothing at all.

[`src/rtl8720c_irq_read.c`](src/rtl8720c_irq_read.c) fixes that without
touching LibreTiny:

- The linker option `-Wl,--wrap=digitalRead` sends every `digitalRead()` call
  of the firmware to `__wrap_digitalRead()` from that file.
- For a pin with an active interrupt, the wrapper reads the level through the
  interrupt object (`gpio_irq_read()`), which leaves the interrupt alone.
- Every other pin, like the button, goes to LibreTiny's original
  `digitalRead()` unchanged.

The idea comes from phdindota, who found the cause and fixed it with a patch
script for LibreTiny's source. That script edits the LibreTiny copy in the
shared PlatformIO folder, so it affects every LibreTiny build on the machine
and needs an absolute path in the ESPHome dashboard. The linker wrap keeps the
fix inside this firmware and works from a GitHub package. The CI of this
repository compiles the firmware and checks in the binary that the receiver
path really calls the wrapper.

#### `rtl87xx`

```yaml
rtl87xx:
  board: generic-rtl8720cf-2mb-992k
  family: rtl8720c
  framework:
    version: latest
```

The RTL8720CF runs ESPHome through LibreTiny. The board
`generic-rtl8720cf-2mb-992k` matches the 2 MB flash layout of the BL3357-P
module. `family` is implied by the board; it stays in the file because
ESPHome then refuses a wrong board instead of building something that does
not boot. `version: latest` picks the newest LibreTiny release that ships with
the installed ESPHome version (v1.13.0 in ESPHome 2026.9), not a development
snapshot.

#### `logger`

```yaml
logger:
  level: INFO
  baud_rate: 0
```

`INFO` keeps the logs short and saves CPU time. `baud_rate: 0` switches off the
hardware UART: logging over it interferes with the receiver interrupts on this
chip. The logs are still available over Wi-Fi in the ESPHome dashboard. For
debugging received codes, set `level: DEBUG` and enable `dump: raw` in the
receiver.

#### `api`, `ota`, `wifi`, `captive_portal`

```yaml
api:

ota:
  - platform: esphome
    id: ota_esphome

wifi:
  ap:

captive_portal:
```

The native API connects the device to Home Assistant. The package leaves keys
and passwords to your own config. `example.yaml` adds an API encryption key and
switches on OTA encryption, which reuses that key (new in ESPHome 2026.9 and
cheaper on flash than a separate OTA password). The OTA entry has an ID, so your
config extends it with `!extend ota_esphome` instead of creating a second one.

If the device can't reach your Wi-Fi, it opens a fallback hotspot named after
the device. Connect to it and the captive portal lets you enter new Wi-Fi
credentials, so a new router never means opening the case again. Give the
hotspot a password (`fallback_ap_password` in the example), because the portal
also accepts firmware uploads.

#### `status_led` and `binary_sensor`

```yaml
status_led:
  pin:
    number: PA7
    inverted: true

binary_sensor:
  - platform: gpio
    id: button
    name: Button
    pin:
      number: PA19
      inverted: true
      mode: INPUT_PULLUP
```

The LED shows the ESPHome status: it blinks while something is wrong (no
Wi-Fi, no API connection) and stays off when everything is fine. The physical
button becomes a binary sensor in Home Assistant and can trigger any
automation.

#### `remote_receiver`

```yaml
remote_receiver:
  id: ir_rx
  pin:
    number: PA18
  filter: 200us
  idle: ${ir_receiver_idle}
```

- `filter: 200us` drops pulses shorter than 200 µs. Ambient light (sun, some
  lamps) causes such short flashes; without the filter they end up as garbage
  codes.
- `idle` is the silence that ends a code. 25 ms separates the presses of TV and
  audio remotes cleanly. Air conditioners send one press as several frames
  with gaps of up to about 35 ms; if such codes arrive split into pieces, set
  `ir_receiver_idle: 80ms` in your own config (HAIR uses the same value).
- `buffer_size` is not set on purpose. ESPHome's default holds 1000 pulses,
  enough for the longest air conditioner codes. A fixed value would mean
  different things depending on the ESPHome version: from ESPHome 2026.10 on
  (in beta at the time of writing) it counts bytes, 4 per pulse; before that it
  counted pulses. The `buffer_size: 2048` found in older configs therefore
  shrinks from 2048 to 512 pulses on new releases.
- `dump: raw` (commented out) prints every received code to the log.

#### `remote_transmitter`

```yaml
remote_transmitter:
  id: ir_tx
  pin: PA4
  carrier_duty_percent: 50%
  non_blocking: true
```

The transmitter modulates its output with a 38 kHz carrier at 50 % duty, the
usual value for IR. Since ESPHome 2026.9 the carrier comes from a PWM peripheral and the
timing from a hardware timer. `non_blocking: true` lets the transmission run in
the background, so the API, Wi-Fi and the receiver stay responsive even while
a long air conditioner code goes out.

#### `infrared`

```yaml
infrared:
  - platform: ir_rf_proxy
    id: ir_proxy_tx
    name: IR Emitter
    remote_transmitter_id: ir_tx

  - platform: ir_rf_proxy
    id: ir_proxy_rx
    name: IR Receiver
    remote_receiver_id: ir_rx
    receiver_frequency: 38kHz
```

This is what makes the device an IR proxy. Each entry becomes one entity on
Home Assistant's native `infrared` platform: the emitter sends raw timings that
Home Assistant (or an integration such as HAIR) hands over, the receiver passes
every captured code to Home Assistant. Codes are never compiled into the
firmware, so learning new devices needs no reflash. `receiver_frequency` does
not change the hardware, it only tells Home Assistant that the receiver
demodulates 38 kHz signals.

### Customizing

Everything in the package can be changed from your own config:

```yaml
substitutions:
  name: rm4-living-room
  friendly_name: RM4 Living Room
  ir_receiver_idle: 80ms        # long air conditioner codes

packages:
  broadlink_rm4_mini:
    url: https://github.com/seb5594/ESPHome-Broadlink-RM4-Mini
    ref: main
    files: [broadlink-rm4-mini.yaml]

# Add components ...
sensor:
  - platform: wifi_signal
    name: Wi-Fi signal
    update_interval: 60s

# ... or change existing ones by their ID
binary_sensor:
  - id: !extend button
    on_press:
      - logger.log: "Button pressed"
```

`!extend <id>` changes an item of the package, `!remove <id>` drops it.

## Home Assistant

After the first boot, Home Assistant shows a new ESPHome device under
**Settings → Devices & services**. Click **Add**, enter the API encryption key
from your secrets, and the device brings these entities (names depend on your
`friendly_name`):

| Entity | Example ID | What it does |
|---|---|---|
| IR Emitter | `infrared.broadlink_rm4c_mini_ir_emitter` | Sends IR codes. Its state is the time of the last transmission. |
| IR Receiver | `infrared.broadlink_rm4c_mini_ir_receiver` | Receives IR codes. Its state is the time of the last received code. |
| Button | `binary_sensor.broadlink_rm4c_mini_button` | The physical button. |

Current Home Assistant releases list all emitters and receivers under
**Settings → Connectivity → Infrared**. Integrations for IR-controlled devices, such as
[LG Infrared](https://www.home-assistant.io/integrations/lg_infrared/) or
[Samsung Infrared](https://www.home-assistant.io/integrations/samsung_infrared/),
ask for an emitter during setup; pick the RM4 there.

## Using it with HAIR

[HAIR](https://github.com/DAB-LABS/HAIR) is a custom integration with its own
sidebar panel: capture codes from any remote, turn them into devices with
buttons, media players, climate entities and more, and send them through any
emitter. It talks to the native `infrared` platform only, so it works with
this firmware without any extra ESPHome configuration.

### Setup

1. Install HAIR through HACS and restart Home Assistant:
   [![Open HAIR in HACS](https://my.home-assistant.io/badges/hacs_repository.svg)](https://my.home-assistant.io/redirect/hacs_repository/?owner=DAB-LABS&repository=HAIR&category=integration)
2. **Settings → Devices & services → Add integration → HAIR**. The setup finds
   the RM4's emitter and receiver on its own.
3. Open **HAIR** in the sidebar. On the **Devices** tab the RM4 appears with a
   `TX-NATIVE` emitter and an `RX-NATIVE` receiver.

### Learning a remote

1. Open the **Sniffer** tab, point your remote at the RM4 and press a few
   buttons (a new remote needs about three presses before HAIR lists it).
2. Click **USE** → **Make a Device**, pick the RM4 as emitter.
3. HAIR creates a device with one button entity per captured code. Map
   commands to actions (power, volume, …) to get a matching media player,
   climate or fan entity.

For air conditioners, set `ir_receiver_idle: 80ms` first, otherwise one press
may show up as several signals.

### Moving codes over from the Broadlink integration

Codes you learned with `remote.learn_command` while the RM4 still ran the
Broadlink firmware don't have to be learned again. The Broadlink integration
keeps them in `.storage/broadlink_remote_<mac>_codes`, and HAIR's **Plucker**
reads these files (read-only) and turns them into HAIR devices that send
through the RM4's new emitter. The files stay in place when the Broadlink
integration is removed, but make a backup of `.storage` first anyway.

Codes learned in the Broadlink app live in Broadlink's cloud and can't be
imported this way.

Automations need one small change afterwards: HAIR gives every device its own
`remote` entity, so the `device:` parameter goes away.

```yaml
# before (Broadlink integration)
action: remote.send_command
target:
  entity_id: remote.rm4c_mini
data:
  device: tv
  command: power

# after (HAIR device "TV")
action: remote.send_command
target:
  entity_id: remote.tv   # the remote entity HAIR created for the device
data:
  command: power
```

## Troubleshooting

**ltchiptool can't connect**
TX and RX swapped is the most common cause. Then check that `IOA0` is bridged
to `3.3V` *before* the RM4 is powered, that `IOA13` is not pulled to GND and
that the adapter really uses 3.3 V levels.

**The build stops with a `min_version` error**
Your ESPHome is older than 2026.9.0. Update the ESPHome app or
`pip install -U esphome`.

**The device crashes or reboots when sending**
Same cause: firmware built with an ESPHome release before 2026.9.0. Rebuild
with a current version.

**Nothing arrives at the receiver**
Make sure your config still pulls in the whole package, the
[receiver fix](#the-receiver-fix) comes with it. Then set `level: DEBUG` in
`logger` and uncomment `dump: raw`, and watch the log while pressing buttons
from about one metre away. If it stays silent, open an issue with the log.

**Air conditioner codes arrive in pieces**
Raise `ir_receiver_idle` to `80ms`.

**The device doesn't show up after flashing**
It opens a hotspot named after the device when it can't connect. Check the
Wi-Fi credentials in your secrets; only 2.4 GHz networks work.

## Known limitations

- The SHT30 temperature/humidity input of the stock firmware is not mapped
  yet; its pins are unknown.
- `PA15` (network button of the stock firmware) is left alone because it is
  also the RX line of the flashing UART.
- The RM4 Mini has no RF hardware. For 433 MHz look at the RM4 Pro.
- Hardware UART logging stays off, see [`logger`](#logger).

## Thanks

A big thank you to **phdindota** and
[phdindota/broadlink-rm4mini-esphome](https://github.com/phdindota/broadlink-rm4mini-esphome).
Without that project this one wouldn't exist: it was the first to put ESPHome
on the RM4 Mini, worked out the pin map from the stock firmware, documented how
to open and flash the device, found the cause of the silent IR receiver and
provided the photo of the board used above (MIT licensed).

Thanks as well to

- [LibreTiny](https://github.com/libretiny-eu/libretiny) for bringing ESPHome
  to the RTL8720CF,
- [ESPHome](https://esphome.io/) for the RTL8720C transmitter work and the IR
  proxy,
- [DAB-LABS](https://github.com/DAB-LABS) for [HAIR](https://github.com/DAB-LABS/HAIR).

## License

[MIT](LICENSE)
