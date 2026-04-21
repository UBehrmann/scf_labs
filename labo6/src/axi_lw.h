/*****************************************************************************************
 * HEIG-VD
 * Haute Ecole d'Ingenerie et de Gestion du Canton de Vaud
 * School of Business and Engineering in Canton de Vaud
 *****************************************************************************************
 * REDS Institute
 * Reconfigurable Embedded Digital Systems
 *****************************************************************************************
 *
 * File                 : axi_lw.h
 *
 *****************************************************************************************
 * Brief: Header file for bus AXI lightweight HPS to FPGA defines definition
 *
 *****************************************************************************************
 * Context              : SCF Lab 5 — AXI4-Lite custom IP (register map)
 *
 *****************************************************************************************/

#ifndef __AXI_LW_H__
#define __AXI_LW_H__

#include <stdint.h>
#include <stddef.h>

// Base address (lightweight HPS-to-FPGA bridge, HPS view)
#define AXI_LW_HPS_FPGA_BASE_ADD    0xFF200000 /* source : p. 2-16 */

/* Offsets on the same bridge for the default FPGA fabric GPIO (labo 6, devmem) */
#define LW_BRIDGE_SWITCH_OFFSET     0x0004B000
#define LW_BRIDGE_KEYS_OFFSET       0x0004B004

// AXI registers (offsets from base)
#define REG_CST	                0x0000 /* Constant [31..0]                                                                                    -- IP - Constant         */
#define REG_TEST	            0x0004 /* Test [31..0]                                                                                        -- IP - Test             */
#define REG_KEYS	            0x0008 /* Keys state [3..0] - Unused [31..4]	                                                                -- DE1-SoC - Keys             */
#define REG_KEYS_EDGE_CAPTURE	0x000C /* Keys edge [3..0] - Unused [31..4]	                                                                -- DE1-SoC - Keys-EdgeCapture */
#define REG_SWITCHS	            0x0010 /* Switchs state [9..0] - Unused [31..10]	                                                            -- DE1-SoC - Switchs          */
#define REG_LEDS	            0x0014 /* Leds [9..0] - Unused [31..10]	                                                                        -- DE1-SoC - Leds             */
#define REG_LEDS_OUTSET	        0x0018 /* Leds set [9..0] - Unused [31..10]	                                                                    -- DE1-SoC - Leds-OutSet      */
#define REG_LEDS_OUTCLR	        0x001C /* Leds clear [9..0] - Unused [31..10]	                                                                -- DE1-SoC - Leds-OutClear    */
#define REG_HEX3_0	            0x0020 /* [31] unused [30-24] HEX3 - [23] unused [22-16] HEX2 - [15] unused [14-8] HEX1 - [7] unused [6-0] HEX0	-- DE1-SoC - Hex 3-0          */
#define REG_HEX5_4	            0x0024 /* [31-15] unused [14-8] HEX5 - [7] unused [6-0] HEX4	                                                -- DE1-SoC - Hex 5-4          */

// ACCESS MACROS
#ifdef LINUX_APP
extern volatile uint8_t *axi_lw_virt_base;
#define AXI_LW_REG(_x_) (*(volatile uint32_t *)(axi_lw_virt_base + (uintptr_t)(_x_)))
#else
#define AXI_LW_REG(_x_) (*(volatile uint32_t *)(AXI_LW_HPS_FPGA_BASE_ADD + (uintptr_t)(_x_)))
#endif

// Define bits usage
#define BITS_SWITCHS   	0x000003FF
#define BITS_LEDS      	0x000003FF
#define BITS_KEY       	0x0000000F

#define BITS_HEX0		0x0000007F
#define BITS_HEX1		0x00007F00
#define BITS_HEX2		0x007F0000
#define BITS_HEX3		0x7F000000
#define BITS_HEX4		0x0000007F
#define BITS_HEX5		0x00007F00

#define BITS_HEX3_0		(BITS_HEX0 | BITS_HEX1 | BITS_HEX2 | BITS_HEX3)
#define BITS_HEX5_4		(BITS_HEX4 | BITS_HEX5)

#define HEX_BITS_OFFSET 8

// Individual key's bits
#define KEY0 0x1
#define KEY1 0x2
#define KEY2 0x4
#define KEY3 0x8

#endif /* __AXI_LW_H__ */
