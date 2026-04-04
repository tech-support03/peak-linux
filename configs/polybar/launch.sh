#!/bin/sh
# peak-linux — Polybar launcher

# Kill existing instances
killall -q polybar

# Wait until all processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch on each monitor
if type "xrandr" > /dev/null 2>&1; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        MONITOR=$m polybar --reload main &
    done
else
    polybar --reload main &
fi
