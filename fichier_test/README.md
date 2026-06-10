# SCF exam prep — `fichier_test`

Templates and step-by-step guides for the DE1-SoC continuous assessment (based on TE2 2024 + labo5/7/9).

**Exam day → start here: [EXAM_QUICKSTART.md](EXAM_QUICKSTART.md)** (condensed checklist; links to full guides).

## Layout

```
fichier_test/
├── README.md
├── guides/
│   ├── 00_exam_2024_fir_notes.md
│   ├── 01_qsys_platform_designer.md
│   ├── 02_build_and_deploy.md
│   ├── 03_run_userspace.md
│   ├── 04_generic_template.md
│   ├── 05_vhdl_snippets.md
│   └── 06_vhdl_comb_pipe_seq.md
├── template_generic/         # ★ start here if topic unknown
│   ├── fpga/
│   ├── soft/
│   └── overlay/
├── template/                 # convolution-oriented (labo9 map)
│   ├── fpga/
│   ├── soft/
│   └── overlay/
└── reference/                # minimal 3×3 convolution example
    ├── fpga/
    ├── soft/
    └── overlay/
```

## 2024 test vs 2025 guess

| Topic | 2024 test (TE2) | Lab course (likely 2025 theme) |
|-------|-----------------|--------------------------------|
| Algorithm | 3-tap FIR: `y = C0·x + C1·x1 + C2·x2` | 3×3 image convolution (labo9) |
| Device | `/dev/FIRSCF` | `/dev/convol` |
| SW API | `read`/`write` 4 bytes + 2 `ioctl` (coeffs, reset) | same pattern + sysfs attrs in labo9 |
| HW | AXI4-Lite slave + datapath | AXI4-Lite + FIFOs / line buffers |
| Extra | IRQ on output, single open | status bits, optional IRQ |

Use **`template_generic/`** when the topic is unknown (FIR, conv, or other stream IP).
Use **`template/`** when you know the map is labo9-style convolution.
Use **`reference/`** to rehearse end-to-end convolution before the test.

## Quick rehearsal order

1. Qsys: add custom IP, export `altera_axi4lite_slave`, assign `0x0000` on `hps_0.f2h_axi_slave`.
2. Quartus: compile → `.sof` → `.rbf`.
3. Cross-compile driver + userspace (`guides/02_build_and_deploy.md`).
4. Copy to board, load FPGA bitstream (U-Boot preload or overlay).
5. `insmod` driver, run userspace (`guides/03_run_userspace.md`).

## Register map (convolution — shared `axi.h`)

| Index | Offset | Access | Purpose |
|-------|--------|--------|---------|
| 0 | 0x00 | R | Constant `0xD06512ED` |
| 1 | 0x04 | RW | Test register |
| 2 | 0x08 | W[31] reset, R[9:0] status | Control / status |
| 3–5 | 0x0C–0x14 | RW | Kernel columns 0–2 (3× int8 each) |
| 6 | 0x18 | R | Max line width |
| 7 | 0x1C | RW | Image width |
| 8 | 0x20 | W | Data in (4 pixels / write) |
| 9 | 0x24 | R | Data out (1 pixel, sign-extended) |

HPS base address: **`0xFF200000`** (first slot on `f2h_axi_slave`, labo5 default).
