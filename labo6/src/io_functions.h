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

#ifndef IO_FUNCTIONS_H
#define IO_FUNCTIONS_H

#include <stdint.h>

#define AXI_CST 0xBADB100Du

int init_IO(void);
int deinit_IO(void);

/* Lecture des switchs / touches via le design de base (offsets 0x4B000 / 0x4B004). */
uint32_t read_lw_bridge_switches(void);
uint32_t read_lw_bridge_keys(void);

uint32_t read_cst(void);
void     write_test(uint32_t val);
uint32_t read_test(void);

uint8_t  read_keys(void);
void     keys_ack(uint8_t keys);
uint8_t  read_keys_edges(void);

uint16_t read_switch(void);
void     set_leds(uint16_t leds);
void     clear_leds(uint16_t leds);

void     seg7_write_int(uint32_t value);
void     seg7_clear(void);

#endif
