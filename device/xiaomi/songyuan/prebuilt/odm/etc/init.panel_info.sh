#!/system/bin/sh
# Copyright (c) 2009-2015, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Update the panel color property and Leds brightness
for i in $(seq 5); do
    if [ -f /sys/class/touch/touch_dev/panel_color ]; then
	color=`cat /sys/class/touch/touch_dev/panel_color`
	if [ -n "$color" ]; then
	    /system/bin/log -p i -t panel-info-sh Get panel_color successfully $color
	    break
	else
	    /system/bin/log -p i -t panel-info-sh Get panel_color unsuccessfully, try again...
	    sleep 1
	    continue
	fi
    else
	color="0"
	/system/bin/log -p i -t panel-info-sh Get panel_color unsuccessfully, try again...
	sleep 1
    fi
done

for i in $(seq 5); do
    if [ -f /sys/class/touch/touch_dev/panel_vendor ]; then
	panel_vendor=`cat /sys/class/touch/touch_dev/panel_vendor`
	if [ -n "$panel_vendor" ]; then
	    /system/bin/log -p i -t panel-info-sh Get panel_vendor successfully $panel_vendor
	    break
	else
	    /system/bin/log -p i -t panel-info-sh Get panel_vendor unsuccessfully, try again...
	    sleep 1
	    continue
	fi
    else
	panel_vendor="0"
	/system/bin/log -p i -t panel-info-sh Get panel_vendor unsuccessfully, try again...
	sleep 1
    fi
done

for i in $(seq 5); do
    if [ -f /sys/class/touch/touch_dev/panel_display ]; then
	panel_display=`cat /sys/class/touch/touch_dev/panel_display`
	if [ -n "$panel_display" ]; then
	    /system/bin/log -p i -t panel-info-sh Get panel_display successfully $panel_display
	    break
	else
	    /system/bin/log -p i -t panel-info-sh Get panel_display unsuccessfully, try again...
	    sleep 1
	    continue
	fi
	else
	panel_display="0"
	/system/bin/log -p i -t panel-info-sh Get panel_display unsuccessfully, try again...
	sleep 1
    fi
done

for i in $(seq 5); do
    if [ -f /sys/class/touch/touch_dev/touch_vendor ]; then
	touch_vendor=`cat /sys/class/touch/touch_dev/touch_vendor`
	if [ -n "$touch_vendor" ]; then
	    /system/bin/log -p i -t panel-info-sh Get touch_vendor successfully $touch_vendor
	    break
	else
	    /system/bin/log -p i -t panel-info-sh Get touch_vendor unsuccessfully, try again...
	    sleep 1
	    continue
	fi
    else
	touch_vendor="0"
	/system/bin/log -p i -t panel-info-sh Get touch_vendor unsuccessfully, try again...
	sleep 1
    fi
done

case "$color" in
    "1")
        setprop vendor.panel.color WHITE
        ;;
    "2")
        setprop vendor.panel.color BLACK
        ;;
    "3")
        setprop vendor.panel.color RED
        ;;
    "4")
        setprop vendor.panel.color YELLOW
        ;;
    "5")
        setprop vendor.panel.color GREEN
        ;;
    "6")
        setprop vendor.panel.color PINK
        ;;
    "7")
        setprop vendor.panel.color PURPLE
        ;;
    "8")
        setprop vendor.panel.color GOLDEN
        ;;
    "9")
        setprop vendor.panel.color SLIVER
        ;;
    "@")
        setprop vendor.panel.color GRAY
        ;;
    "A")
        setprop vendor.panel.color SLIVER_BLUE
        ;;
    "B")
        setprop vendor.panel.color CORAL_BLUE
        ;;
    *)
        setprop vendor.panel.color UNKNOWN
        ;;
esac
case "$panel_vendor" in
    "1")
        setprop vendor.panel.vendor 1
        ;;
    "2")
        setprop vendor.panel.vendor 2
        ;;
    "3")
        setprop vendor.panel.vendor 3
        ;;
    "4")
        setprop vendor.panel.vendor 4
        ;;
    "5")
        setprop vendor.panel.vendor 5
        ;;
    "6")
        setprop vendor.panel.vendor 6
        ;;
    "7")
        setprop vendor.panel.vendor 7
        ;;
    "8")
        setprop vendor.panel.vendor 8
        ;;
    "9")
        setprop vendor.panel.vendor 9
		;;
    "@")
        setprop vendor.panel.vendor 10
        ;;
    "A")
        setprop vendor.panel.vendor 11
        ;;
    "B")
        setprop vendor.panel.vendor 12
        ;;
    "C")
        setprop vendor.panel.vendor 13
        ;;
    "D")
        setprop vendor.panel.vendor 14
        ;;
    "E")
        setprop vendor.panel.vendor 15
        ;;
    "F")
        setprop vendor.panel.vendor 16
        ;;
    "G")
        setprop vendor.panel.vendor 17
        ;;
    "H")
        setprop vendor.panel.vendor 18
        ;;
    "I")
        setprop vendor.panel.vendor 19
        ;;
    "P")
        setprop vendor.panel.vendor 20
        ;;
    "Q")
        setprop vendor.panel.vendor 21
        ;;
    "R")
        setprop vendor.panel.vendor 22
        ;;
    "S")
        setprop vendor.panel.vendor 23
        ;;
    *)
        setprop vendor.panel.vendor UNKNOWN
        ;;
esac
case "$panel_display" in
    "1")
        setprop vendor.panel.display 1
        ;;
    "2")
        setprop vendor.panel.display 2
        ;;
    "3")
        setprop vendor.panel.display 3
        ;;
    "4")
        setprop vendor.panel.display 4
        ;;
    "5")
        setprop vendor.panel.display 5
        ;;
    "6")
        setprop vendor.panel.display 6
        ;;
    "7")
        setprop vendor.panel.display 7
        ;;
    "8")
        setprop vendor.panel.display 8
        ;;
    "9")
        setprop vendor.panel.display 9
		;;
    "@")
        setprop vendor.panel.display 10
        ;;
	"A")
        setprop vendor.panel.display 11
		;;
	"B")
        setprop vendor.panel.display 12
		;;
	"E")
        setprop vendor.panel.display 6
		;;
    *)
        setprop vendor.panel.display UNKNOWN
        ;;
esac
case "$touch_vendor" in
    "1")
        setprop vendor.panel.touch_vendor 1
        ;;
    "2")
        setprop vendor.panel.touch_vendor 2
        ;;
    "3")
        setprop vendor.panel.touch_vendor 3
        ;;
    "4")
        setprop vendor.panel.touch_vendor 4
        ;;
    "5")
        setprop vendor.panel.touch_vendor 5
        ;;
    *)
        setprop vendor.panel.touch_vendor UNKNOWN
        ;;
esac

setprop vendor.panel.info.ready 1
