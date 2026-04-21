/*****************************************************************************************
 * HEIG-VD / REDS — SCF Lab 6 — I/O helpers (Linux / bare metal)
 *****************************************************************************************/

#ifndef IO_FUNCTIONS_H
#define IO_FUNCTIONS_H

#include <stdint.h>

#define AXI_CST 0xBADB100Du

#ifdef LINUX_APP
int init_IO(void);
int deinit_IO(void);

/* Lecture des switchs / touches via le design de base (offsets 0x4B000 / 0x4B004). */
uint32_t read_lw_bridge_switches(void);
uint32_t read_lw_bridge_keys(void);

/* Court test LED / HEX sur l'IP AXI (apres chargement du .rbf labo 5). */
void hw_led_hex_selftest(void);
#endif

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
