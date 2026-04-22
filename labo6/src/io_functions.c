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
 * Date                 : 21.04.2026
 *
 * Context              : AXI4-Lite FPGA IO laboratory
 *
 *****************************************************************************************
 * Brief: I/O helpers for AXI4-Lite FPGA IO laboratory
 *
 *****************************************************************************************
 * Modifications :
 * Ver    Date        Student      Comments
 * 1.0    13.04.2026  UBN          Initial version.
 * 1.1    21.04.2026  UBN          Update version.
 *
*****************************************************************************************/

#include <stdint.h>

#include "axi_lw.h"
#include "hex_val.h"
#include "io_functions.h"

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>

static inline void mmio_sync_after_write(void)
{
    __sync_synchronize();
}

#define MAP_PAGE_SIZE 4096UL
#define MAP_PAGE_MASK (MAP_PAGE_SIZE - 1UL)

/*
 * Map enough of the lightweight bridge so both the custom IP (low offsets) and
 * the fabric GPIO used in lab 6 (0x4B000 / 0x4B004) sit in the same mapping.
 */
#define MAP_SIZE 0x500000UL

static int      dev_mem_fd = -1;
static void    *map_base   = MAP_FAILED;
volatile uint8_t *axi_lw_virt_base;

int init_IO(void)
{
    if (axi_lw_virt_base != NULL) {
        return 0;
    }

    dev_mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (dev_mem_fd < 0) {
        perror("open /dev/mem");
        return 1;
    }

    map_base = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, dev_mem_fd,
                    (off_t)(AXI_LW_HPS_FPGA_BASE_ADD & ~MAP_PAGE_MASK));
    if (map_base == MAP_FAILED) {
        perror("mmap");
        close(dev_mem_fd);
        dev_mem_fd = -1;
        return 2;
    }

    axi_lw_virt_base = (volatile uint8_t *)map_base
        + (uintptr_t)(AXI_LW_HPS_FPGA_BASE_ADD & MAP_PAGE_MASK);
    return 0;
}

int deinit_IO(void)
{
    int err = 0;

    if (map_base != MAP_FAILED) {
        if (munmap(map_base, MAP_SIZE) != 0) {
            perror("munmap");
            err = 1;
        }
        map_base         = MAP_FAILED;
        axi_lw_virt_base = NULL;
    }
    if (dev_mem_fd >= 0) {
        close(dev_mem_fd);
        dev_mem_fd = -1;
    }
    return err;
}

uint32_t read_lw_bridge_switches(void)
{
    return *(volatile uint32_t *)(axi_lw_virt_base + LW_BRIDGE_SWITCH_OFFSET);
}

uint32_t read_lw_bridge_keys(void)
{
    return *(volatile uint32_t *)(axi_lw_virt_base + LW_BRIDGE_KEYS_OFFSET);
}

static void seg7_write_3_0(uint32_t value)
{
    AXI_LW_REG(REG_HEX3_0) = value & BITS_HEX3_0;
    mmio_sync_after_write();
}

static void seg7_write_5_4(uint32_t value)
{
    AXI_LW_REG(REG_HEX5_4) = value & BITS_HEX5_4;
    mmio_sync_after_write();
}

uint32_t read_cst(void)
{
    return AXI_LW_REG(REG_CST);
}

void write_test(uint32_t val)
{
    AXI_LW_REG(REG_TEST) = val;
    mmio_sync_after_write();
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
    mmio_sync_after_write();
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
    uint32_t cur = AXI_LW_REG(REG_LEDS);
    cur |= (uint32_t)(leds & BITS_LEDS);
    AXI_LW_REG(REG_LEDS) = cur;
    mmio_sync_after_write();
}

void clear_leds(uint16_t leds)
{
    uint32_t cur = AXI_LW_REG(REG_LEDS);
    cur &= ~(uint32_t)(leds & BITS_LEDS);
    AXI_LW_REG(REG_LEDS) = cur;
    mmio_sync_after_write();
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

void seg7_clear(void)
{
    seg7_write_3_0(0u);
    seg7_write_5_4(0u);
}

void hw_led_hex_selftest(void)
{
    unsigned i;
    uint32_t eight;
    uint32_t hex;

    /* LED : une LED a la fois */
    AXI_LW_REG(REG_LEDS) = 0u;
    mmio_sync_after_write();
    for (i = 0u; i < 10u; i++) {
        AXI_LW_REG(REG_LEDS) = (1u << (i % 10u));
        mmio_sync_after_write();
        usleep(80000);
    }
    AXI_LW_REG(REG_LEDS) = 0u;
    mmio_sync_after_write();

    /* HEX : quatre 8 sur HEX3..0, deux 8 sur HEX5..4 */
    eight = (uint32_t)VAL2SEG[8u];
    hex   = eight | (eight << 8) | (eight << 16) | (eight << 24);
    AXI_LW_REG(REG_HEX3_0) = hex & BITS_HEX3_0;
    mmio_sync_after_write();
    AXI_LW_REG(REG_HEX5_4) = (eight | (eight << 8)) & BITS_HEX5_4;
    mmio_sync_after_write();
    usleep(400000);
    seg7_write_3_0(0u);
    seg7_write_5_4(0u);
}
