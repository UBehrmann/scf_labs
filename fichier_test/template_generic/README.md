# Generic exam template

Topic-agnostic starting point for SCF continuous assessment.

**Start here** if you do not know whether the exam is FIR, convolution, or another stream IP.

| Step | Action |
|------|--------|
| 1 | Copy this folder |
| 2 | Read `../guides/04_generic_template.md` + VHDL: `05` / `06` |
| 3 | Fill register map from exam sheet into `soft/axi_regs.h` |
| 4 | Implement VHDL datapath (`fpga/axi4lite_slave.vhd` TODO block) |
| 5 | Rename `DEV_NAME` in driver + userspace |

Other folders:

- `../template/` — convolution-oriented map (labo9)
- `../reference/` — minimal working convolution example
- `../guides/` — Qsys, deploy, run
