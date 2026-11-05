# shellcheck disable=SC2034
SKIPUNZIP=1

APPLY_PATCH "system" "system/framework/telephony-common.jar" "$MODPATH/0001-Treat-unknown-UICC-apps-state-as-enabled.patch"
