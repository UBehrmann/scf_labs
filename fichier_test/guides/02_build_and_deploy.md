# Build and copy driver + userspace to DE1-SoC

Paths assume repo root `/home/baer/Projects/scf_labs`. Adjust `KERNELDIR` / toolchain to your machine.

## Prerequisites on PC

| Tool | Typical path |
|------|----------------|
| ARM cross GCC | `arm-linux-gnueabihf-gcc` |
| Kernel tree | e.g. `/home/baer/linux-6.18/` (same version as board) |
| `scp` / `ssh` | Board on USB Ethernet `192.168.0.3` or serial |

## 1. Userspace program

```bash
cd fichier_test/reference/soft
# or template/soft after you fill it in
make clean all
# → convol_test (ARM binary)
```

`Makefile` variables:

```makefile
CC      ?= arm-linux-gnueabihf-gcc
CFLAGS  ?= -O2 -Wall -Wextra -std=c99 -D_DEFAULT_SOURCE
```

## 2. Kernel module (out-of-tree)

```bash
cd fichier_test/reference/soft/driver
# Edit Makefile: KERNELDIR, ARCH=arm, CROSS_COMPILE=arm-linux-gnueabihf-
make clean all
# → convol_driver.ko
```

If build fails on `modpost`: kernel headers must match running board (`uname -r` on DE1).

### With device-tree overlay (labo9)

Add to driver `Makefile`:

```makefile
dtb-y += convol.dtbo
```

Put `convol.dtso` next to driver; kernel build emits `convol.dtbo`.

## 3. FPGA bitstream

After Quartus compile:

```bash
# In Quartus: File → Convert Programming Files → DE1_SoC_top.rbf
```

Copy `.rbf` to board `/lib/firmware/` if using DT overlay (`firmware-name` property).

## 4. Copy files to board

### Option A — `scp` over USB Ethernet

```bash
BOARD=root@192.168.0.3   # adjust
scp reference/soft/convol_test          $BOARD:/home/root/
scp reference/soft/driver/convol_driver.ko $BOARD:/home/root/
scp hard/eda/output_files/DE1_SoC_top.rbf  $BOARD:/lib/firmware/   # if overlay
scp reference/overlay/convol.dtbo          $BOARD:/lib/firmware/   # if overlay
```

### Option B — SD card (labo9 `files_to_uSD.sh` pattern)

```bash
mount /dev/mmcblk0p3 /mnt
cp convol_test convol_driver.ko /mnt/home/root/
umount /mnt
```

### Option C — serial + `rz` / paste (exam fallback)

Minicom + `sz`/`rz`, or base64 pipe — slow but works.

## 5. Program FPGA (without overlay)

From PC (USB Blaster):

```bash
cd /home/baer/Projects/scf_labs/de1_scripts
python3 pgm_fpga.py   # loads preloader; use Quartus Programmer for .sof
```

Or on board if bitstream in `/lib/firmware` and overlay loads it (see guide 03).

## 6. Load driver on board

```bash
insmod /home/root/convol_driver.ko
dmesg | tail
# expect: constant OK, /dev/convol
ls -l /dev/convol
```

Unload: `rmmod convol_driver`

## 7. Checklist before demo

- [ ] `cat /sys/class/fpga_manager/fpga0/state` → `operating`
- [ ] `dmesg` no `invalid CST` (wrong bitstream or address)
- [ ] `/dev/convol` exists, mode 666
- [ ] `chmod +x convol_test` if needed
