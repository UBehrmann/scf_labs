#ifndef __AXI_H__
#define __AXI_H__

#define AXI_HPS_FPGA_BASE_ADD   0xFF200000

#define REG_CONSTANT        0
#define REG_TEST            1
#define REG_STATUS_CONTROL  2
#define REG_KERN_COL_0      3
#define REG_KERN_COL_1      4
#define REG_KERN_COL_2      5
#define REG_MAX_WIDTH       6
#define REG_WIDTH           7
#define REG_DATA_IN         8
#define REG_DATA_OUT        9

#define BITS_CMD_RST            0x80000000u
#define BITS_ST_RUNNING         0x00000001u
#define BITS_ST_DONE            0x00000002u
#define BITS_ST_OUT_ALM_FULL    0x00000004u
#define BITS_ST_OUT_EMPTY       0x00000020u

#define CONSTANT_VALUE      0xD06512EDu

#define KERN_W  3
#define KERN_H  3

#endif
