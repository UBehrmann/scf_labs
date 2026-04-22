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
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>

#include "axi_lw.h"
#include "io_functions.h"

static volatile sig_atomic_t bridge_stop;

static void bridge_sighandler(int sig)
{
    (void)sig;
    bridge_stop = 1;
}

/* Boucle lecture switchs / touches sur le bridge (meme adresses que devmem). */
static void bridge_poll_loop(void)
{
    bridge_stop = 0;
    if (signal(SIGINT, bridge_sighandler) == SIG_ERR) {
        perror("signal");
        return;
    }

    printf("Boucle bridge lwhps2fpga (offsets 0x4B000 / 0x4B004) — bouger SW / KEYS.\n");
    printf("Ctrl+C pour passer au test IP AXI.\n");

    while (!bridge_stop) {
        printf("\r  SW (bridge) 0x%08" PRIX32 "   KEYS (bridge) 0x%08" PRIX32 "   ",
               read_lw_bridge_switches(), read_lw_bridge_keys());
        fflush(stdout);
        usleep(150000);
    }
    printf("\n(bridge) arrete.\n\n");
    (void)signal(SIGINT, SIG_DFL);
}

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
    int ret = init_IO();
    if (ret != 0) {
        fprintf(stderr, "init_IO a echoue (%d)\n", ret);
        return EXIT_FAILURE;
    }

    bridge_poll_loop();

    printf("Lab 5 / 6 — AXI4-Lite FPGA IO\n");

    uint32_t cste = read_cst();
    printf("Constante : 0x%08" PRIX32 " (lu)\n", cste);
    printf("Constante : 0x%08" PRIX32 " (attendu)\n", (uint32_t)AXI_CST);

    uint32_t testVal = 0x00C0FFEEu;
    write_test(testVal);
    printf("Test : 0x%08" PRIX32 " (ecrit)\n", testVal);
    uint32_t testValCheck = read_test();
    printf("Test : 0x%08" PRIX32 " (lu)\n", testValCheck);

    if (cste != AXI_CST || testVal != testValCheck) {
        (void)deinit_IO();
        return -1;
    }

    printf("Test sortie LED/HEX sur l'IP AXI (si rien ne bouge, reprogrammer le FPGA avec le .rbf labo 5).\n");
    hw_led_hex_selftest();

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

        /* Laisser du temps au FPGA pour les fronts touches (Linux plus rapide que le bare metal). */
        usleep(15000);
    }
}
