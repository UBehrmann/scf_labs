#!/bin/bash
# Load DT overlay + firmware on DE1-SoC (labo9 pattern)

NAME="${1:-convol}"
DTBO="${NAME}.dtbo"
RBF="${2:-DE1_SoC_top.rbf}"

usage() {
	echo "usage: $0 [overlay_name] [rbf_filename]"
	exit 1
}

case "$1" in
	-h|--help) usage ;;
esac

mount -t configfs none /sys/kernel/config 2>/dev/null

cp -f "$DTBO" "/lib/firmware/$DTBO"
cp -f "$RBF" "/lib/firmware/$RBF"

echo "FPGA state before: $(cat /sys/class/fpga_manager/fpga0/state)"
mkdir -p "/sys/kernel/config/device-tree/overlays/$NAME"
echo "$DTBO" > "/sys/kernel/config/device-tree/overlays/$NAME/path"
echo "FPGA state after:  $(cat /sys/class/fpga_manager/fpga0/state)"
dmesg | tail -15
