# TE2 2024 — FIR filter (actual exam topic)

Source: `SCF_TE2.pdf` (11-06-2024).

## Spec summary

- **Device**: `/dev/FIRSCF`
- **Algorithm**: 3-tap FIR  
  `y[n] = C0·x[n] + C1·x[n-1] + C2·x[n-2]`
- **Coefficients**: 3 write-only 32-bit registers `C0`, `C1`, `C2` (or one ioctl programming all three)
- **Data path**: `write(4 bytes)` → HW computes → `read(4 bytes)` when output ready
- **ioctl**: set coefficients; reset `t` registers to 0
- **IRQ**: interrupt when output bytes available
- **Concurrency**: only one userspace process (`-EBUSY` on second `open`)
- **Points**: PL 25, driver 20, userspace 5

## Adapt `template/` for FIR

| Piece | Change |
|-------|--------|
| `axi.h` | Replace kernel cols with `REG_C0`, `REG_C1`, `REG_C2`; keep `REG_DATA_IN` / `REG_DATA_OUT` |
| FPGA | 2 delay registers `x1`, `x2` + multiply-add — no line buffers |
| Driver | `DEV_NAME "FIRSCF"`; ioctl cmd 1 = write 3 coeffs; `request_irq` |
| Userspace | Write test vector from exam sheet; poll or wait IRQ |

## If 2025 test is convolution instead

Same AXI skeleton; swap datapath for labo9-style line buffers / FIFOs.  
Register map already in `template/soft/axi.h`. Full pipeline: `Labo_scf_2024/labo9/`.
