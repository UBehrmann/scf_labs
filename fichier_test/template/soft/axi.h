#ifndef __AXI_H__
#define __AXI_H__

/* HPS view of lightweight AXI bridge (labo5 first peripheral) */
#define AXI_HPS_FPGA_BASE_ADD   0xFF200000

/* Word index = byte_offset / 4 — keep driver + FPGA case statements in sync */
#define REG_CONSTANT        0  /* 0x00 R  — exam signature */
#define REG_TEST            1  /* 0x04 RW */
#define REG_STATUS_CONTROL  2  /* 0x08 W[31] reset, R[9:0] status */
#define REG_KERN_COL_0      3  /* 0x0C kernel row bytes for col 0 */
#define REG_KERN_COL_1      4
#define REG_KERN_COL_2      5
#define REG_MAX_WIDTH       6  /* 0x18 R */
#define REG_WIDTH           7  /* 0x1C RW image width */
#define REG_DATA_IN         8  /* 0x20 W  4 pixels per write */
#define REG_DATA_OUT        9  /* 0x24 R  1 pixel out */

#define BITS_CMD_RST            0x80000000u
#define BITS_ST_RUNNING         0x00000001u
#define BITS_ST_DONE            0x00000002u
#define BITS_ST_OUT_ALM_FULL    0x00000004u
#define BITS_ST_OUT_EMPTY       0x00000020u

#define CONSTANT_VALUE      0xD06512EDu

#define KERN_W  3
#define KERN_H  3

#endif
