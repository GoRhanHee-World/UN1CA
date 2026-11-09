# shellcheck disable=SC2034
SKIPUNZIP=1

LOG_STEP_IN "- Preserving AP-assigned context IDs for the bundled vendor RIL"
# SecRilAdaptor::CopyDataReqData reads the CID from profileId bits 11..18.
# Plain profile IDs produce CID 0 and fail with "Unavailable cid(0)".
SMALI_PATCH "system" "system/framework/telephony-common.jar" \
    "smali/com/android/internal/telephony/RILUtils.smali" "return" \
    "IsApAssistSupported()Z" "true" || exit 1

LOG_STEP_OUT
