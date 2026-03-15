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
*****************************************************************************************/

#ifndef __AXI_LW_H__
#define __AXI_LW_H__

#include <stdint.h>

// Base address
#define AXI_LW_HPS_FPGA_BASE_ADD    0xFF200000 /* source : p. 2-16 */

// AXI registers
#define REG_SWITCHS    0x0000 /* Switchs state[9..0] - Unused[31..10]    	                                                             -- DE1-SoC - Switchs */
#define REG_LEDS       0x0020 /* Leds[9..0] - Unused[31..10]             	                                                             -- DE1-SoC - Leds	  */
#define REG_HEX3_0     0x0100 /* [31] unused [30-24] HEX3 - [23] unused [22-16] HEX2 - [15] unused [14-8] HEX1 - [7] unused [6-0] HEX0 */
#define REG_HEX5_4     0x0120 /* [31-15] unused [14-8] HEX5 - [7] unused [6-0] HEX4 */
#define REG_BOUTONS    0x0200 /* Buttons state[3..0] - Unused[31..4] */


// ACCESS MACROS
#define AXI_LW_REG(_x_)   *(volatile uint32_t *)(AXI_LW_HPS_FPGA_BASE_ADD + _x_) /* _x_ is a "CPU" offset with respect to the base address */

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

// Individual key bits
#define KEY0 0x1
#define KEY1 0x2
#define KEY2 0x4
#define KEY3 0x8

#endif /* __AXI_LW_H__ */
