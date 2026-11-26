# I-188: sdcardfs-era Android/media/<app> folders keep the app's ext gid (1023:303xx), which the
# FUSE daemon cannot write through once sdcardfs is off (tablet 2.0.0-beta2, phone 2.0.0-beta5,
# I-166). A oneshot after user 0 unlock moves them to group 1023 with g+rwX. Why in full:
# files/system/bin/minsos_mediaperm.
SKIPUNZIP=1

case "$TARGET_CODENAME" in
    gts7*|y2q|x1q|z3q) ;;
    *) return 0 ;;
esac

LOG_STEP_IN "- I-188: Android/media group fix after unlock (minsos_mediaperm)"
ADD_TO_WORK_DIR "$MODPATH/files" "system" "bin/minsos_mediaperm" 0 0 755 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$MODPATH/files" "system" "etc/init/minsos_mediaperm.rc" 0 0 644 "u:object_r:system_file:s0"
EVAL "chmod 755 \"$WORK_DIR/system/system/bin/minsos_mediaperm\""
for _F in system/bin/minsos_mediaperm system/etc/init/minsos_mediaperm.rc; do
    [ -f "$WORK_DIR/system/$_F" ] \
        || ABORT "[$TARGET_CODENAME] $_F did not land in the work dir"
    cmp -s "$MODPATH/files/$_F" "$WORK_DIR/system/$_F" \
        || ABORT "[$TARGET_CODENAME] landed $_F differs from the source"
    grep -q "^system/${_F#system/} " "$WORK_DIR/configs/fs_config-system" 2>/dev/null \
        || ABORT "[$TARGET_CODENAME] $_F has no fs_config entry - the image build would refuse it"
done
unset _F
grep -qE '^system/bin/minsos_mediaperm 0 0 0?755 ' "$WORK_DIR/configs/fs_config-system" \
    || ABORT "[$TARGET_CODENAME] minsos_mediaperm is not 0755 in fs_config - init could not exec it"
grep -q '^on property:sys\.user\.0\.ce_available=true$' "$WORK_DIR/system/system/etc/init/minsos_mediaperm.rc" \
    || ABORT "[$TARGET_CODENAME] minsos_mediaperm.rc lost its ce_available trigger"
grep -q 'seclabel u:r:minsos_mediaperm:s0' "$WORK_DIR/system/system/etc/init/minsos_mediaperm.rc" \
    || ABORT "[$TARGET_CODENAME] minsos_mediaperm.rc has no seclabel - the service would die with status 127"

# ---- the domain init needs to start it (same shape as patches/pkgcache_invalidate) ---------------
_PLAT_CIL="$WORK_DIR/system/system/etc/selinux/plat_sepolicy.cil"
[ -f "$_PLAT_CIL" ] || ABORT "[$TARGET_CODENAME] plat_sepolicy.cil is not in the work dir"
grep -q "(type minsos_mediaperm)" "$_PLAT_CIL" \
    && ABORT "[$TARGET_CODENAME] plat_sepolicy.cil already declares minsos_mediaperm - the work dir was not rebuilt from the donor"
for _T in media_rw_data_file media_userdir_file system_data_root_file toolbox_exec mlstrustedsubject; do
    grep -qE "\(type(attribute)? $_T\)" "$_PLAT_CIL" \
        || ABORT "[$TARGET_CODENAME] plat_sepolicy.cil has no $_T - the minsos_mediaperm rules would not compile"
done
unset _T
cat <<'EOF' >> "$_PLAT_CIL"
; Added by unica/mods/minsos_mediaperm/customize.sh (I-188) - domain for the minsos_mediaperm
; service. Runs once per unlock as root, walks /data/media/0/Android/media and moves entries that
; are not in group 1023 into it with g+rwX.
(type minsos_mediaperm)
(roletype r minsos_mediaperm)
; The trailing space before )) below is deliberate. Do not remove it.
; unica/mods/prophide rewrites every line starting with (typeattributeset domain using
; s/))/prophide ))/ - without the space its name is glued onto ours and secilc fails (2026-08-17).
(typeattributeset domain (minsos_mediaperm ))
(typeattributeset coredomain (minsos_mediaperm ))
; Per-app folders under Android/media carry the app's MLS categories (measured: s0:c29,c257,c512,c768).
; Without this the chgrp is refused on MLS grounds even with every allow rule below.
(typeattributeset mlstrustedsubject (minsos_mediaperm ))
(allow init minsos_mediaperm (process (transition)))
(allow minsos_mediaperm shell_exec (file (entrypoint read open execute map getattr)))
(allow minsos_mediaperm system_file (file (entrypoint execute execute_no_trans read open map getattr)))
; find, chgrp, chmod, wc and log are toybox symlinks, labelled toolbox_exec.
(allow minsos_mediaperm toolbox_exec (file (read open execute execute_no_trans getattr map)))
; fsetid: chmod g+s on a directory whose group the caller is not in needs CAP_FSETID, or the kernel drops the bit
; (I-191, Android/data entries go to group 1078). The rc also puts the service in ext_data_rw for the same reason.
(allow minsos_mediaperm self (capability (chown fowner fsetid dac_override dac_read_search)))
(allow minsos_mediaperm system_data_root_file (dir (search getattr)))
(allow minsos_mediaperm media_userdir_file (dir (search getattr)))
(allow minsos_mediaperm media_rw_data_file (dir (search read open getattr setattr)))
(allow minsos_mediaperm media_rw_data_file (file (getattr setattr)))
(allow minsos_mediaperm media_rw_data_file (lnk_file (getattr setattr)))
(allow minsos_mediaperm socket_device (dir (search)))
(allow minsos_mediaperm logdw_socket (sock_file (write)))
(allow minsos_mediaperm logd (unix_dgram_socket (sendto)))
(allow minsos_mediaperm null_device (chr_file (read write open getattr)))
EOF
grep -q "(type minsos_mediaperm)" "$_PLAT_CIL" \
    || ABORT "[$TARGET_CODENAME] the minsos_mediaperm CIL block did not land in plat_sepolicy.cil"
grep -q "(typeattributeset mlstrustedsubject (minsos_mediaperm ))" "$_PLAT_CIL" \
    || ABORT "[$TARGET_CODENAME] minsos_mediaperm is not mlstrustedsubject - chgrp on per-app folders would be refused"
unset _PLAT_CIL

LOG "- minsos_mediaperm: ce_available oneshot + sepolicy domain (I-188)"
LOG_STEP_OUT
