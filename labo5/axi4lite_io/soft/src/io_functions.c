/*****************************************************************************************
 * HEIG-VD
 * Haute Ecole d'Ingenerie et de Gestion du Canton de Vaud
 * School of Business and Engineering in Canton de Vaud
 *****************************************************************************************
 * REDS Institute
 * Reconfigurable Embedded Digital Systems
 *****************************************************************************************
 *
 * File                 : io_functions.c
 * Author               : UBN
 * Date                 : 13.04.2026    
 *
 * Context              : AXI4-Lite FPGA IO laboratory
 *
 *****************************************************************************************
 * Brief: Test application for AXI4-Lite FPGA IO laboratory
 *
 *****************************************************************************************
 * Modifications :
 * Ver    Date        Student      Comments
 * 1.0    13.04.2026  UBN          Initial version.
 *
*****************************************************************************************/

#include <stdint.h>

#include "axi_lw.h"
#include "hex_val.h"
#include "io_functions.h"

static void seg7_write_3_0(uint32_t value)
{
    AXI_LW_REG(REG_HEX3_0) = value & BITS_HEX3_0;
}

static void seg7_write_5_4(uint32_t value)
{
    AXI_LW_REG(REG_HEX5_4) = value & BITS_HEX5_4;
}

uint32_t read_cst(void)
{
    return AXI_LW_REG(REG_CST);
}

void write_test(uint32_t val)
{
    AXI_LW_REG(REG_TEST) = val;
}

uint32_t read_test(void)
{
    return AXI_LW_REG(REG_TEST);
}

uint8_t read_keys(void)
{
    return (uint8_t)(AXI_LW_REG(REG_KEYS) & BITS_KEY);
}

void keys_ack(uint8_t keys)
{
    AXI_LW_REG(REG_KEYS_EDGE_CAPTURE) = (uint32_t)(keys & BITS_KEY);
}

uint8_t read_keys_edges(void)
{
    uint8_t edges = (uint8_t)(AXI_LW_REG(REG_KEYS_EDGE_CAPTURE) & BITS_KEY);
    keys_ack(edges);
    return edges;
}

uint16_t read_switch(void)
{
    return (uint16_t)(AXI_LW_REG(REG_SWITCHS) & BITS_SWITCHS);
}

void set_leds(uint16_t leds)
{
    AXI_LW_REG(REG_LEDS_OUTSET) = (uint32_t)(leds & BITS_LEDS);
}

void clear_leds(uint16_t leds)
{
    AXI_LW_REG(REG_LEDS_OUTCLR) = (uint32_t)(leds & BITS_LEDS);
}

void seg7_write_int(uint32_t value)
{
    uint32_t hex = 0u;
    unsigned i;

    for (i = 0u; i < 4u; i++) {
        hex |= (uint32_t)VAL2SEG[value % 10u] << (HEX_BITS_OFFSET * (int)i);
        value /= 10u;
    }
    seg7_write_3_0(hex);
    seg7_write_5_4(0u);
}
