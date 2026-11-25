# shellcheck shell=bash
# MinsOS bf5b995d (I-187): some cars select a primary-HAL offload output even
# though this vendor's Bluetooth stack opens a software-encoding session.
SET_PROP "vendor" "persist.bluetooth.a2dp_offload.disabled" "true" || return 1
