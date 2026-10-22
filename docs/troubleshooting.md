# Troubleshooting

**ltchiptool can't connect**
TX and RX swapped is the most common cause. Then check that the boot pin is
bridged to `3.3V` *before* the RM4 is powered (`IOA0` on the RM4 Mini, see the
device README for other models), that `IOA13` is not pulled to GND and that
the adapter really uses 3.3 V levels.

**The build stops with a `min_version` error**
Your ESPHome is older than 2026.9.0. Update the ESPHome app or
`pip install -U esphome`.

**The device crashes or reboots when sending**
Same cause: firmware built with an ESPHome release before 2026.9.0. Rebuild
with a current version.

**Nothing arrives at the receiver**
Make sure your config still pulls in the whole package, the
[receiver fix](configuration.md#the-receiver-fix) comes with it. Then set `level: DEBUG` in
`logger` and uncomment `dump: raw`, and watch the log while pressing buttons
from about one metre away. If it stays silent, open an issue with the log.

**Air conditioner codes arrive in pieces**
Raise `ir_receiver_idle` to `80ms`.

**The device doesn't show up after flashing**
It opens a hotspot named after the device when it can't connect. Check the
Wi-Fi credentials in your secrets; only 2.4 GHz networks work.
