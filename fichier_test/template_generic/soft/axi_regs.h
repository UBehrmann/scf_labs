#ifndef __AXI_REGS_H__
#define __AXI_REGS_H__

/*
 * Generic AXI register map — word index = byte_offset / 4.
 * Rename REG_PARAM_* / REG_DATA_* to match exam sheet; keep indices
 * aligned between this file, driver, userspace, and VHDL case statements.
 *
 * Typical mappings:
 *   FIR (TE2 2024)     : PARAM_0..2 = C0,C1,C2 ; write/read 4 bytes data
 *   Convolution (L9)   : PARAM_* = kernel cols ; add REG_CFG at index 6
 *   Simple IO (labo7)  : use labo7 map instead; this template targets stream IP
 */

#define AXI_HPS_FPGA_BASE   0xFF200000u
#define AXI_MAP_SIZE        0x1000u

#define REG_CONSTANT        0   /* 0x00  R   FPGA ID — driver checks at load */
#define REG_TEST            1   /* 0x04  RW  bring-up test */
#define REG_CTRL_STATUS     2   /* 0x08  W[31] cmd, R[31:0] status */
#define REG_PARAM_0         3   /* 0x0C  RW  coeff / kernel column 0 */
#define REG_PARAM_1         4   /* 0x10  RW  coeff / kernel column 1 */
#define REG_PARAM_2         5   /* 0x14  RW  coeff / kernel column 2 */
#define REG_DATA_IN         6   /* 0x18  WO  stream input (often 4 bytes) */
#define REG_DATA_OUT        7   /* 0x1C  RO  stream output */

/* Optional extra slots if exam needs them — shift DATA_* or add above */
#define REG_CFG_A           8   /* e.g. image width, line length */
#define REG_CFG_B           9   /* e.g. max width, mode */

/* --- Control (write to REG_CTRL_STATUS) --- */
#define CMD_RESET           0x80000000u   /* bit 31 */
#define CMD_START           0x40000000u   /* bit 30 — if exam uses explicit start */

/* --- Status (read REG_CTRL_STATUS) --- */
#define ST_BUSY             0x00000001u
#define ST_DONE             0x00000002u
#define ST_OUT_READY        0x00000004u   /* output available — tie to IRQ if required */
#define ST_IN_FULL          0x00000008u

/* Exam constant — pick one and match VHDL */
#define AXI_CONSTANT        0xBADB100Du   /* labo5/7 */
/* #define AXI_CONSTANT     0xD06512EDu */ /* labo9 */

/* Binary packet size for read()/write() — 2024 FIR used 4 */
#define AXI_IO_CHUNK        4

#endif
