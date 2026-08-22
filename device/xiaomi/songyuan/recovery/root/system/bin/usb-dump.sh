#!/system/bin/sh

out="/tmp/usb-dump-$(date +%Y%m%d-%H%M%S).txt"

{
  echo "== getprop usb =="
  getprop | grep -E 'sys\.usb|init\.svc\.adbd|ro\.boot\.usb|ro\.recovery\.usb|service\.adb|twrp\.usb' | sort

  echo
  echo "== processes =="
  ps -A | grep -E 'adbd|mtp|fastbootd' || true

  echo
  echo "== udc =="
  ls -l /sys/class/udc 2>/dev/null || true
  for f in /config/usb_gadget/g1/UDC \
           /config/usb_gadget/g1/idVendor \
           /config/usb_gadget/g1/idProduct \
           /config/usb_gadget/g1/configs/b.1/strings/0x409/configuration; do
    [ -e "$f" ] && echo "$f=$(cat "$f" 2>/dev/null)"
  done

  echo
  echo "== configfs links =="
  ls -l /config/usb_gadget/g1/configs/b.1 2>/dev/null || true

  echo
  echo "== ffs ready files =="
  for f in /config/usb_gadget/g1/functions/ffs.adb/ready \
           /config/usb_gadget/g1/functions/ffs.mtp/ready \
           /config/usb_gadget/g1/functions/ffs.fastboot/ready; do
    [ -e "$f" ] && echo "$f=$(cat "$f" 2>/dev/null)"
  done

  echo
  echo "== usb kernel log =="
  dmesg | grep -Ei 'usb|dwc|gadget|configfs|ffs|mtp|adb' | tail -200 || true
} > "$out"

echo "$out"
