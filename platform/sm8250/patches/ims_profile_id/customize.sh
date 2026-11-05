# shellcheck disable=SC2034
SKIPUNZIP=1

LOG_STEP_IN "- Sending the vendor RIL plain data profile ids (IMS calls on Korean carriers, I-43)"
SMALI_PATCH "system" "system/framework/telephony-common.jar" \
    "smali/com/android/internal/telephony/RILUtils.smali" "return" \
    "IsApAssistSupported()Z" "false"

LOG_STEP_OUT
