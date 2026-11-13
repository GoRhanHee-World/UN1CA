LOG_STEP_IN "- Adding Galaxy S26 sounds"
DELETE_FROM_WORK_DIR "system" "system/hidden/INTERNAL_SDCARD/Music/Samsung/Over_the_Horizon.mp3"
ADD_TO_WORK_DIR "m3qksx" "system" \
    "system/hidden/INTERNAL_SDCARD/Music/Samsung/Over_the_Horizon.m4a" 0 0 644 "u:object_r:system_file:s0"
for SOUND_DIR in notifications ringtones; do
    DELETE_FROM_WORK_DIR "system" "system/media/audio/$SOUND_DIR"
    ADD_TO_WORK_DIR "m3qksx" "system" "system/media/audio/$SOUND_DIR" 0 0 755 "u:object_r:system_file:s0"
done
unset SOUND_DIR
ADD_TO_WORK_DIR "m3qksx" "system" "system/etc/ringtones_count_list.txt" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "m3qksx" "system" \
    "system/media/audio/ui/Media_preview_Over_the_horizon.ogg" 0 0 644 "u:object_r:system_file:s0"

SOUND_PREFIX="ACH_"
if ! $TARGET_AUDIO_SUPPORT_ACH_RINGTONE; then
    LOG "- Removing haptic channels for devices without ACH support"
    while IFS= read -r SOUND_FILE; do
        SOUND_NAME="$(basename "$SOUND_FILE")"
        SOUND_OUTPUT="${SOUND_FILE%/*}/${SOUND_NAME#ACH_}"
        if [ ! -f "$SOUND_OUTPUT" ]; then
            SOUND_HAPTIC="$(ffprobe -v error -select_streams a:0 \
                -show_entries stream_tags=ANDROID_HAPTIC -of default=noprint_wrappers=1:nokey=1 "$SOUND_FILE")"
            if [ "${SOUND_HAPTIC:-0}" -gt 0 ]; then
                SOUND_CHANNELS="$(ffprobe -v error -select_streams a:0 \
                    -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 "$SOUND_FILE")"
                SOUND_AUDIO_CHANNELS=$((SOUND_CHANNELS - SOUND_HAPTIC))
                if [ "$SOUND_AUDIO_CHANNELS" -eq 1 ]; then
                    SOUND_FILTER="pan=mono|c0=c0"
                elif [ "$SOUND_AUDIO_CHANNELS" -eq 2 ] && [ "$SOUND_CHANNELS" -eq 3 ]; then
                    # FFmpeg reorders three-channel Vorbis L,R,haptic to L,haptic,R.
                    SOUND_FILTER="pan=stereo|c0=c0|c1=c2"
                elif [ "$SOUND_AUDIO_CHANNELS" -eq 2 ] && [ "$SOUND_CHANNELS" -eq 4 ]; then
                    SOUND_FILTER="pan=stereo|c0=c0|c1=c1"
                else
                    ABORT "Unsupported ACH channel layout: $SOUND_NAME ($SOUND_CHANNELS/$SOUND_HAPTIC)"
                fi
                EVAL "ffmpeg -nostdin -hide_banner -loglevel error -y -i \"$SOUND_FILE\" -map 0:a:0 -af \"$SOUND_FILTER\" -c:a libvorbis -q:a 7 -map_metadata 0 -map_metadata:s:a 0:s:a -metadata:s:a ANDROID_HAPTIC= -metadata:s:a TYPE= \"$SOUND_OUTPUT\"" || return 1
            else
                EVAL "cp -p \"$SOUND_FILE\" \"$SOUND_OUTPUT\"" || return 1
            fi
        fi
        DELETE_FROM_WORK_DIR "system" "${SOUND_FILE#"$WORK_DIR/system/"}"
        SET_METADATA "system" "${SOUND_OUTPUT#"$WORK_DIR/system/"}" 0 0 644 "u:object_r:system_file:s0"
    done < <(find "$WORK_DIR/system/system/media/audio/notifications" "$WORK_DIR/system/system/media/audio/ringtones" -type f -name 'ACH_*.ogg' | sort)
    EVAL "sed -i 's/ACH_//g' \"$WORK_DIR/system/system/etc/ringtones_count_list.txt\""
    SOUND_PREFIX=""
fi
SET_PROP "vendor" "ro.config.ringtone" "${SOUND_PREFIX}Galaxy_Bells.ogg"
SET_PROP "vendor" "ro.config.notification_sound" "${SOUND_PREFIX}Brightline.ogg"
SET_PROP "vendor" "ro.config.alarm_alert" "${SOUND_PREFIX}Morning_Xylophone.ogg"
SET_PROP "vendor" "ro.config.media_sound" "Media_preview_Over_the_horizon.ogg"
SET_PROP "vendor" "ro.config.ringtone_2" "${SOUND_PREFIX}Atomic_Bell.ogg"
SET_PROP "vendor" "ro.config.notification_sound_2" "${SOUND_PREFIX}Three_Star.ogg"
unset SOUND_FILE SOUND_NAME SOUND_OUTPUT SOUND_HAPTIC SOUND_CHANNELS SOUND_AUDIO_CHANNELS SOUND_FILTER SOUND_PREFIX
APPLY_PATCH "system" "system/priv-app/SecSoundPicker/SecSoundPicker.apk" \
    "$MODPATH/brandsound/SecSoundPicker.apk/0001-Enable-SUPPORT_SAMSUNG_BRAND_SOUND_ONEUI_7.patch"
LOG_STEP_OUT
