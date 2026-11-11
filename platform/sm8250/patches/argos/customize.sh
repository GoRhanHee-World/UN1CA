# shellcheck disable=SC2034
SKIPUNZIP=1

# Stock init already marks argos-daemon disabled, but starts it explicitly
# after boot. The port kernel has no ARGOS QoS interface, so argosd exits
# with ENODEV and init restarts it every five seconds.
sed -i '/^[[:space:]]*start argos-daemon[[:space:]]*$/d' \
    "$WORK_DIR/vendor/etc/init/hw/init.samsung.rc"
