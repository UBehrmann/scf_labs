# Generic exam template (`template_generic/`)

Use this when the exam topic is **unknown**. Copy the whole folder at the start of the session, then adapt names from the subject sheet.

## Files

| File | Role |
|------|------|
| `soft/axi_regs.h` | Register indices + constants — **single source of truth** |
| `soft/ioctl_cmds.h` | ioctl numbers (kernel + userspace) |
| `soft/driver/scf_driver.c` | miscdevice, read/write/ioctl, mutex |
| `soft/scf_test.c` | Userspace demo |
| `fpga/axi4lite_slave.vhd` | AXI slave + **TODO datapath** |
| `fpga/IP_hw.tcl` | Platform Designer component |
| `overlay/scf_ip.dtso` | Optional DT overlay |

Convolution-specific layout stays in `template/`. Full working conv example: `reference/`.

## Default register map (8 words)

| Idx | Offset | Name | Typical use |
|-----|--------|------|-------------|
| 0 | 0x00 | CONSTANT | `0xBADB100D` — driver probe check |
| 1 | 0x04 | TEST | R/W bring-up |
| 2 | 0x08 | CTRL/STATUS | W: reset (bit 31); R: busy/done/ready |
| 3–5 | 0x0C–0x14 | PARAM_0..2 | FIR: C0,C1,C2 — Conv: kernel columns |
| 6 | 0x18 | DATA_IN | Stream in (4 bytes) |
| 7 | 0x1C | DATA_OUT | Stream out |

Add `REG_CFG_A/B` at indices 8–9 if the subject needs width, mode, etc.

## Adapt to FIR (TE2 2024)

1. `axi_regs.h`: rename PARAM → `REG_C0`, `REG_C1`, `REG_C2` (keep indices 3–5).
2. `DEV_NAME` → `"FIRSCF"` in driver + `scf_test.c`.
3. FPGA: 2 delay registers `x1`, `x2`; on DATA_IN write compute  
   `y = C0*x + C1*x1 + C2*x2`; shift delay line; pulse IRQ when output valid.
4. `IOCTL_SCF_SET_PARAMS` already writes 3 registers.
5. See `guides/00_exam_2024_fir_notes.md`.

## Adapt to convolution (labo9)

1. Copy extra register defs from `template/soft/axi.h` (`REG_WIDTH`, `REG_KERN_COL_*`, …).
2. Insert registers **before** DATA_IN or extend map — update **all** case statements.
3. Replace FPGA datapath stub with line buffers / FIFOs (`Labo_scf_2024/labo9/`).
4. Or start from `template/` instead of generic.

## Adapt to simple GPIO (labo7-style)

Use labo7 `axi_ctl.c` + `axi_driver.c` directly — generic template targets **streaming** IP (read/write data path).

## Exam workflow

1. Read subject → fill address table on paper.
2. Update `axi_regs.h` only, then sync VHDL `case` + driver `REG_*`.
3. Implement datapath in VHDL between `data_in_s` and `data_out_s` — see [05_vhdl_snippets.md](05_vhdl_snippets.md) and [06_vhdl_comb_pipe_seq.md](06_vhdl_comb_pipe_seq.md).
4. Set `AXI_CONSTANT` + VHDL `CST_CONSTANT` to same value.
5. Build, `insmod`, run `scf_test` with provided vectors.

## ioctl summary

| Command | Purpose |
|---------|---------|
| `IOCTL_SCF_RESET` | Assert reset bit in CTRL register |
| `IOCTL_SCF_SET_PARAMS` | Write PARAM_0..2 (coeffs / kernel) |
| `IOCTL_SCF_GET_STATUS` | Read status word |

Add new ioctl macros if the subject defines more commands — keep magic `'s'` or change to exam-specified letter.
