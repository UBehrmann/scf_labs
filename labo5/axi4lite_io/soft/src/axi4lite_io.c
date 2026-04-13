/*****************************************************************************************
 * HEIG-VD
 * Haute Ecole d'Ingenerie et de Gestion du Canton de Vaud
 * School of Business and Engineering in Canton de Vaud
 *****************************************************************************************
 * REDS Institute
 * Reconfigurable Embedded Digital Systems
 *****************************************************************************************
 *
 * File                 : axi4lite_io.c
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

#include <inttypes.h>
#include <stdio.h>
#include <stdint.h>

#include "axi_lw.h"
#include "io_functions.h"

int __auto_semihosting;

static uint16_t val   = 0u;
static uint8_t  legal = 1u;

static void key0(void)
{
    val   = read_switch();
    legal = 1u;
}

static void key1(void)
{
    if (val > 0u) {
        --val;
        legal = 1u;
    } else {
        legal = 0u;
    }
}

static void key2(void)
{
    if (val < BITS_SWITCHS) {
        ++val;
        legal = 1u;
    } else {
        legal = 0u;
    }
}

static void key3(void)
{
    val   = 0u;
    legal = 1u;
}

int main(void)
{
    uint32_t cste = read_cst();
    printf("Lab 5 - AXI4-Lite FPGA IO\n");
    printf("Constante : 0x%08" PRIX32 " (lu)\n", cste);
    printf("Constante : 0x%08" PRIX32 " (attendu)\n", (uint32_t)AXI_CST);

    uint32_t testVal = 0x00C0FFEE;
    write_test(testVal);
    printf("Test : 0x%08" PRIX32 " (ecrit)\n", testVal);
    uint32_t testValCheck = read_test();
    printf("Test : 0x%08" PRIX32 " (lu)\n", testValCheck);

    if (cste != AXI_CST || testVal != testValCheck) {
        return -1;
    }

    for (;;) {
        uint8_t keys_edges = read_keys_edges();

        if (keys_edges & KEY0) {
            key0();
        }
        if (keys_edges & KEY1) {
            key1();
        }
        if (keys_edges & KEY2) {
            key2();
        }
        if (keys_edges & KEY3) {
            key3();
        }

        if (legal) {
            clear_leds(BITS_LEDS);
        } else {
            set_leds(BITS_LEDS);
        }
        seg7_write_int((uint32_t)val);
    }
}
