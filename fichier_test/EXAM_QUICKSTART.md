# SCF exam — condensed checklist

**Use this during the test.** Details → linked guides / labo files.

**Points (2024):** PL 25 · driver 20 · userspace 5

---

## 0. First 5 minutes — read subject & pick template

| If exam looks like… | Copy folder | Constant | Device name |
|---------------------|-------------|----------|-------------|
| **Unknown** / stream IP | `template_generic/` | `0xBADB100D` (change if sheet says so) | from sheet |
| **3-tap FIR** (2024 TE2) | `template_generic/` + [FIR notes](guides/00_exam_2024_fir_notes.md) | sheet | `/dev/FIRSCF` |
| **3×3 convolution** | `template/` | `0xD06512ED` | `/dev/convol` |

**HPS base address (default):** `0xFF200000` — first IP on `hps_0.f2h_axi_slave` at Qsys offset `0x0000`.

Draw register table on scratch paper **before coding** → [generic map](template_generic/soft/axi_regs.h) or [conv map](template/soft/axi.h).

---

## 1. FPGA (PL) — ~25 pts

### 1.1 Qsys (15 min)

- [ ] Open labo5 `qsys_system.qsys` or add IP from your `IP_hw.tcl`
- [ ] Instance name e.g. `myip_0` · base **`0x0000`** · span `0x1000`
- [ ] Connect: `clk_0` → clock · `hps_0.h2f_reset` → reset · `altera_axi4lite_slave` → `f2h_axi_slave`
- [ ] IRQ? → export to `hps_0.f2h_irq` (note line # for DTS)
- [ ] Generate HDL → recompile Quartus top

→ **More:** [guides/01_qsys_platform_designer.md](guides/01_qsys_platform_designer.md)

### 1.2 VHDL slave + datapath (main work)

**Keep labo5 AXI handshake** (`aw`/`w`/`ar`/`r` channels) — only change register `case` + datapath.

| Reg idx | Offset | You implement |
|---------|--------|---------------|
| 0 | 0x00 | R: constant (driver check) |
| 1 | 0x04 | RW: test |
| 2 | 0x08 | W[31] reset · R: status (done, ready…) |
| 3–5 | 0x0C–0x14 | params / C0,C1,C2 / kernel cols |
| 6+ | … | DATA_IN (W) · DATA_OUT (R) — per sheet |

**Datapath style (pick one):**

| Algorithm | Style | When |
|-----------|-------|------|
| 3-tap FIR | **Combinational MAC** + shift reg | **Default** — 2024 exam |
| 3×3 conv | Comb `conv_engine` + line buffers | labo9 |
| Many taps | Sequential FSM | rarely in exam |

→ **Snippets:** [guides/05_vhdl_snippets.md](guides/05_vhdl_snippets.md)  
→ **Comb vs pipe vs seq:** [guides/06_vhdl_comb_pipe_seq.md](guides/06_vhdl_comb_pipe_seq.md)  
→ **Copy AXI FSM from:** `labo5/axi4lite_io/hard/src/axi4lite_slave.vhd`  
→ **FIR comb:** `labo8/src_vhdl/fir_filter__cmb.vhd`  
→ **Conv full:** `Labo_scf_2024/labo9/hard/src/axi4lite_slave.vhd`

### 1.3 Bitstream

- [ ] Quartus compile OK
- [ ] File → Convert Programming Files → `.rbf` (Passive Parallel x16)
- [ ] Program once via JTAG **or** copy to `/lib/firmware/` for overlay

---

## 2. Driver — ~20 pts

**Start from:** `template_generic/soft/driver/scf_driver.c` or `labo7/src/driver/axi_driver.c`

### Checklist

- [ ] `DEV_NAME` = exam device (`FIRSCF`, `convol`, …)
- [ ] `AXI_CONSTANT` / `REG_*` = same as VHDL + `axi_regs.h`
- [ ] `ioremap(0xFF200000, 0x1000)` **or** platform driver + `.dtso`
- [ ] Probe: read reg 0 → wrong value = `-ENODEV` (bitstream/address)
- [ ] `misc_register` → `/dev/...` mode `0666`
- [ ] `mutex` + `trylock` on `open` → `-EBUSY` if already open (**2024 required**)
- [ ] `read`/`write` 4 bytes ↔ `DATA_OUT` / `DATA_IN`
- [ ] `ioctl`: reset + set coefficients (at minimum)
- [ ] IRQ? → uncomment `#if 0` blocks in `template_generic/soft/driver/scf_driver.c`

```bash
# driver/Makefile
KERNELDIR ?= /path/to/your/kernel
make -C $(KERNELDIR) M=$(PWD) ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules
```

→ **More:** [guides/02_build_and_deploy.md](guides/02_build_and_deploy.md) · [guides/04_generic_template.md](guides/04_generic_template.md)

---

## 3. Userspace — ~5 pts

**Start from:** `template_generic/soft/scf_test.c`

- [ ] `open("/dev/...", O_RDWR)`
- [ ] `ioctl` reset + program coeffs
- [ ] Loop: `write` input vector → `read` output (binary 4 bytes)
- [ ] Compare to **expected values on exam sheet**
- [ ] Print pass/fail for demo

```bash
cd soft && make    # arm-linux-gnueabihf-gcc
```

---

## 4. Build & copy to board

```bash
# PC
scp scf_driver.ko scf_test root@192.168.0.3:/home/root/
scp DE1_SoC_top.rbf /lib/firmware/    # if overlay
```

→ **More:** [guides/02_build_and_deploy.md](guides/02_build_and_deploy.md)

---

## 5. Run on DE1 (demo)

### A — Simple (bitstream already loaded / JTAG)

```bash
insmod /home/root/scf_driver.ko
dmesg | tail          # "CST OK" /dev ready
./scf_test
rmmod scf_driver
```

### B — Device-tree overlay (labo9)

```bash
mount -t configfs none /sys/kernel/config
cp *.rbf *.dtbo /lib/firmware/
mkdir -p /sys/kernel/config/device-tree/overlays/myip
echo myip.dtbo > /sys/kernel/config/device-tree/overlays/myip/path
insmod scf_driver.ko && ./scf_test
# teardown: rmmod → rmdir overlay
```

→ **More:** [guides/03_run_userspace.md](guides/03_run_userspace.md)

---

## 6. Submission

- [ ] Comment key files (VHDL map, driver ioctl, userspace test)
- [ ] **Address map** documented in report/README
- [ ] Zip project → Cyberlearn

---

## Debug (30 sec each)

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `invalid CST` / `-ENODEV` on insmod | Wrong `.rbf` or wrong base addr | Reprogram FPGA; check Qsys `0x0000` |
| No `/dev/...` | `insmod` failed | `dmesg` |
| `open: No such file` | typo in `DEV_NAME` | match driver `misc_register` |
| `open: Device busy` | second process | by design (2024) |
| Garbage read data | reg index mismatch | align VHDL `case` ↔ `axi_regs.h` |
| AXI hang | broken handshake | copy labo5 AW/W/AR processes unchanged |

---

## Quick reference — where to copy code

| Need | File in repo |
|------|----------------|
| AXI slave FSM | `labo5/axi4lite_io/hard/src/axi4lite_slave.vhd` |
| Platform Designer TCL | `labo5/.../AXI4Lite_hw.tcl` or `template_generic/fpga/IP_hw.tcl` |
| Driver + ioctl | `labo7/src/driver/axi_driver.c` |
| Generic driver skeleton | `template_generic/soft/driver/scf_driver.c` |
| FIR combinational | `labo8/src_vhdl/fir_filter__cmb.vhd` |
| FIR sequential FSM | `labo8/src_vhdl/fir_filter__seq.vhd` |
| Conv engine | `fichier_test/reference/fpga/conv_engine.vhd` |
| Conv full system | `Labo_scf_2024/labo9/` |
| DT overlay example | `labo9/example/example.dtso` · `template_generic/overlay/scf_ip.dtso` |
| 2024 FIR spec | [guides/00_exam_2024_fir_notes.md](guides/00_exam_2024_fir_notes.md) |

---

## All guides (deep dive)

| Guide | Content |
|-------|---------|
| [00_exam_2024_fir_notes.md](guides/00_exam_2024_fir_notes.md) | Actual 2024 TE2 FIR spec |
| [01_qsys_platform_designer.md](guides/01_qsys_platform_designer.md) | Qsys naming, wiring, addresses |
| [02_build_and_deploy.md](guides/02_build_and_deploy.md) | Cross-compile, scp, kernel module |
| [03_run_userspace.md](guides/03_run_userspace.md) | mount, overlay, insmod, run |
| [04_generic_template.md](guides/04_generic_template.md) | Adapt generic template |
| [05_vhdl_snippets.md](guides/05_vhdl_snippets.md) | VHDL patterns explained |
| [06_vhdl_comb_pipe_seq.md](guides/06_vhdl_comb_pipe_seq.md) | Comb / pipeline / FSM choice |
