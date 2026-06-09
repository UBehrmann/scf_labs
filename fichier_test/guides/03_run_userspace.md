# Run userspace program on DE1-SoC (labo7 / labo9)

## A. Labo7 style — fixed address, no overlay

Assumes U-Boot already configured FPGA with your design (or you programmed via JTAG).

### Load driver

```bash
insmod ./convol_driver.ko
dmesg | tail -5
ls -l /dev/convol
```

### Run test

```bash
./convol_test
```

Expected: prints constant `0xD06512ED`, test reg R/W, small convolution sanity check.

### Unload

```bash
rmmod convol_driver
```

---

## B. Device-tree overlay (labo9)

Requires kernel with `CONFIG_OF_CONFIGFS` (patch `labo9/of_configfs.patch`).

### 1. Mount configfs

```bash
mount -t configfs none /sys/kernel/config
# optional in /etc/fstab:
# configfs /sys/kernel/config configfs defaults 0 0
```

### 2. Copy firmware (once per update)

```bash
cp DE1_SoC_top.rbf /lib/firmware/
cp convol.dtbo    /lib/firmware/
```

### 3. Insert overlay

```bash
cat /sys/class/fpga_manager/fpga0/state    # operating

mkdir -p /sys/kernel/config/device-tree/overlays/convol
echo convol.dtbo > /sys/kernel/config/device-tree/overlays/convol/path

dmesg | tail -20
# FPGA reprogrammed, platform device registered
```

### 4. Load module + run

```bash
insmod convol_driver.ko
./convol_test
```

### 5. Remove overlay (reverse order)

```bash
rmmod convol_driver
rmdir /sys/kernel/config/device-tree/overlays/convol
```

Helper script: `reference/overlay/load_overlay.sh`

---

## C. Userspace API summary (convolution reference)

### Device node

```c
int fd = open("/dev/convol", O_RDWR);
```

Single open only (driver returns `-EBUSY` on second open) — same as 2024 FIR spec.

### ioctl — reset FIFO / state

```c
ioctl(fd, 0, CMD_RST);   /* CMD_RST = 0x80000000 */
```

### write — push 4 input pixels (32-bit packed, little-endian)

```c
uint32_t word = px0 | (px1 << 8) | (px2 << 16) | (px3 << 24);
write(fd, &word, 4);
```

### read — one output pixel (sign-extended to 32 bits)

```c
uint32_t out;
read(fd, &out, 4);
uint8_t pixel = (uint8_t)out;
```

### Sysfs (optional, full labo9 driver)

Base: `/sys/class/misc/convol/device/`

| File | R/W | Purpose |
|------|-----|---------|
| `conv_kernel` | RW | 9× int8 kernel |
| `width` | RW | image width |
| `status` | R | status register |

Reference `convol_test.c` uses **ioctl + read/write only** for exam simplicity.

### Poll status without IRQ (exam pattern)

Read sysfs `status` or mmap — reference driver exposes status via `ioctl` helper or read from `/sys/.../status` if implemented.

Status bits (`axi.h`):

- bit 0: running
- bit 1: done
- bit 5: output empty
- bit 2: output almost full → time to `read` outputs

---

## D. 2024 FIR test mapping (if topic repeats)

| FIR spec | Implementation |
|----------|----------------|
| `/dev/FIRSCF` | change `DEV_NAME` in driver |
| ioctl set coeffs | 3× `iowrite32` to coeff regs **or** one ioctl with 3× uint32 |
| ioctl reset | `iowrite32` bit to control reg |
| write 4 B → read 4 B | same `read`/`write` as convolution data regs |
| IRQ on output | `request_irq` in probe, `kill_fasync` or wake queue in handler |

Adapt register indices in `axi.h`; AXI slave skeleton stays identical to labo5.

---

## E. Debug commands

```bash
dmesg -w
cat /sys/kernel/debug/fpga/fpga0/firmware_name
xxd /sys/firmware/devicetree/base/soc/fpga-region0/fpga/bridge@0/convol@0/reg
devmem 0xff200000 32          # constant register (needs devmem2)
```

`invalid CST` → wrong `.rbf` loaded or wrong `AXI_HPS_FPGA_BASE_ADD`.
