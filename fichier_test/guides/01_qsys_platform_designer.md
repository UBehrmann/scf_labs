# Qsys / Platform Designer — step by step (labo5)

Reference project: `labo5/axi4lite_io/hard/eda/qsys_system.qsys`.

## 1. Open the system

1. Quartus → **Tools → Platform Designer** (formerly Qsys).
2. Open existing `qsys_system.qsys` from labo5 (or File → New if starting fresh).
3. Keep **`hps_0`** and default clocks (`clk_0` 50 MHz).

## 2. Add your custom IP

1. **IP Catalog** → search your component (e.g. `AXI4Lite` or `AXI4_Lite_KJD`).
2. If missing: **New Component** from `*_hw.tcl` in `hard/eda/`.
3. Double-click to add instance — name it e.g. **`convol_0`** (instance name ≠ VHDL entity name).

### Naming traps (lose hours here)

| What | Rule |
|------|------|
| **TOP_LEVEL** in `*_hw.tcl` | Must match VHDL entity (`axi4lite_slave`). |
| **Interface** | Use `altera_axi4lite_slave` (type `axi4lite end`). |
| **Clock / reset** | `clock_sink` + `reset_sink`, linked to `clk_0` and `hps_0.h2f_reset`. |
| **Conduit ports** | Only if top needs GPIO/LED — convolution IP usually has **no** conduit. |
| **Instance name** | Appears in generated `qsys_system.vhd` as `convol_0_...`. |
| **Base address** | First IP: **`0x00000000`** on `hps_0.f2h_axi_slave` → HPS sees **`0xFF200000`**. |
| **Address span** | `0x1000` (4 KiB) is enough for ≤16 registers. |

## 3. Connections checklist

```
clk_0.clk              → your_ip.clock_sink
hps_0.h2f_reset        → your_ip.reset_sink
your_ip.altera_axi4lite_slave → hps_0.f2h_axi_slave
```

- **Export nothing** to top for pure memory-mapped IP (unlike labo5 LEDs on `conduit_end`).
- If IRQ required (2024 FIR test): export `irq` from IP → connect to `hps_0.f2h_irq` (pick free line, note number for DTS).

## 4. Generate

1. **Generate HDL** → Verilog or VHDL (match project).
2. **Generate** button → creates `qsys_system/` synthesis files.
3. In Quartus top (`DE1_SoC_top.vhd`): instantiate `qsys_system` (copy from labo5).

## 5. `*_hw.tcl` essentials

Copy `template/fpga/IP_hw.tcl` or `labo5/.../AXI4Lite_hw.tcl`:

- `add_fileset_file ... TOP_LEVEL_FILE` points to `axi4lite_slave.vhd`.
- `add_interface altera_axi4lite_slave axi4lite end`
- Port names **`axi_awaddr_i`**, **`axi_wdata_i`**, … must match VHDL exactly.
- `add_interface_port` widths: `axi_addr_width` / `axi_data_width` parameters or literal `12` / `32`.

## 6. Address map for report

Document in exam submission:

```
HPS physical: 0xFF200000 + Qsys offset
Qsys convol_0: 0x0000 .. 0x0FFF
Register N → byte offset N*4
```

## 7. Compile & bitstream

1. Analysis & Synthesis → Fitter → Assembler.
2. **File → Convert Programming Files** → Raw Binary `.rbf`, Passive Parallel x16 (labo9 PDF).
3. Program FPGA once via `de1_scripts/pgm_fpga.py` or JTAG to verify before Linux.

## 8. Optional: device-tree overlay (labo9)

If driver uses `compatible = "de1_convol"` and `platform_get_resource`:

- FPGA region + bridge nodes in `.dtso` (`template/overlay/convol.dtso`).
- `fpga-shell` / `firmware-name` = your `.rbf`.
- See `guides/03_run_userspace.md` for load sequence.

For exam with **fixed address** driver (labo7 style, `0xFF200000`), overlay is optional if U-Boot already loads your `.rbf`.

## Related guides

- [05_vhdl_snippets.md](05_vhdl_snippets.md) — AXI `case`, shift reg, MAC patterns
- [06_vhdl_comb_pipe_seq.md](06_vhdl_comb_pipe_seq.md) — comb vs pipeline vs FSM for FIR/conv datapath
