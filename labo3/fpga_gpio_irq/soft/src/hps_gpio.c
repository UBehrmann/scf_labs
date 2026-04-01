/*****************************************************************************************
 * HEIG-VD
 * Haute Ecole d'Ingenerie et de Gestion du Canton de Vaud
 * School of Business and Engineering in Canton de Vaud
 *****************************************************************************************
 * REDS Institute
 * Reconfigurable Embedded Digital Systems
 *****************************************************************************************
 *
 * File                 : hps_gpio.c
 *
 *****************************************************************************************
 * Brief: KEY/SW driven control of LEDs and 7-segment displays through AXI lightweight
 *
*****************************************************************************************/

#include <stdint.h>
#include <stdio.h>
#include "axi_lw.h"

int __auto_semihosting;

/* ---- OSC1 TIMER0 (used for LED0..2 blink timing) ------------------------ */
#define TIMER0_BADDR        0xFFD00000
#define TIMER_LOAD          0x00
#define TIMER_VALUE         0x04
#define TIMER_CONTROL       0x08
#define TIMER_CLK_HZ        25000000u

#define REG32(addr)         (*((volatile uint32_t *)(addr)))

#define SW_SEG_MASK         0x7Fu
#define SW_INDEX_MASK       0x7u
#define SW_INDEX_SHIFT      7u

#define LED_ERR_MASK        0x0007u
#define LED_SEL_BASE_SHIFT  3u
#define LED_INVALID_BIT     (1u << 9)

static void timer_init(void) {
    REG32(TIMER0_BADDR + TIMER_CONTROL) = 0;
    REG32(TIMER0_BADDR + TIMER_LOAD) = 0xFFFFFFFFu;
    REG32(TIMER0_BADDR + TIMER_CONTROL) = (1u << 0) | (1u << 2);
}

static void delay_ms(uint32_t ms) {
    uint32_t cycles = (TIMER_CLK_HZ / 1000u) * ms;
    uint32_t start = REG32(TIMER0_BADDR + TIMER_VALUE);
    while ((start - REG32(TIMER0_BADDR + TIMER_VALUE)) < cycles) {
    }
}

static uint32_t pack_hex3_0(const uint8_t hex_state[6]) {
    return ((uint32_t)(hex_state[0] & SW_SEG_MASK)) |
           ((uint32_t)(hex_state[1] & SW_SEG_MASK) << 8) |
           ((uint32_t)(hex_state[2] & SW_SEG_MASK) << 16) |
           ((uint32_t)(hex_state[3] & SW_SEG_MASK) << 24);
}

static uint32_t pack_hex5_4(const uint8_t hex_state[6]) {
    return ((uint32_t)(hex_state[4] & SW_SEG_MASK)) |
           ((uint32_t)(hex_state[5] & SW_SEG_MASK) << 8);
}

static void apply_hex_state(const uint8_t hex_state[6]) {
    AXI_LW_REG(REG_HEX3_0) = pack_hex3_0(hex_state) & BITS_HEX3_0;
    AXI_LW_REG(REG_HEX5_4) = pack_hex5_4(hex_state) & BITS_HEX5_4;
}

static uint16_t selector_leds_from_index(uint8_t index) {
    if (index <= 5u) {
        return (uint16_t)(1u << (LED_SEL_BASE_SHIFT + index));
    }
    return (uint16_t)LED_INVALID_BIT;
}

static void blink_error_leds(uint16_t selector_leds) {
    for (int i = 0; i < 3; ++i) {
        AXI_LW_REG(REG_LEDS) = (selector_leds | LED_ERR_MASK) & BITS_LEDS;
        delay_ms(120u);
        AXI_LW_REG(REG_LEDS) = selector_leds & BITS_LEDS;
        delay_ms(120u);
    }
}

static uint8_t read_key_rising_edge(void) {
    static uint8_t last_keys = 0u;
    uint8_t current_keys = (uint8_t)(AXI_LW_REG(REG_BOUTONS) & BITS_KEY);
    uint8_t rising = (uint8_t)((~last_keys) & current_keys);
    last_keys = current_keys;
    return rising;
}

static void rotate_left_spec_key1(uint8_t hex_state[6]) {
    uint8_t last = hex_state[5];
    for (int i = 5; i > 0; --i) {
        hex_state[i] = hex_state[i - 1];
    }
    hex_state[0] = last;
}

static void rotate_right_spec_key2(uint8_t hex_state[6]) {
    uint8_t first = hex_state[0];
    for (int i = 0; i < 5; ++i) {
        hex_state[i] = hex_state[i + 1];
    }
    hex_state[5] = first;
}

int main(void) {
    uint8_t hex_state[6] = {0u, 0u, 0u, 0u, 0u, 0u};

    printf("Labo GPIO - KEY/SW vers LED et HEX\n");

    timer_init();
    apply_hex_state(hex_state);

    while (1) {
        uint16_t sw = (uint16_t)(AXI_LW_REG(REG_SWITCHS) & BITS_SWITCHS);
        uint8_t index = (uint8_t)((sw >> SW_INDEX_SHIFT) & SW_INDEX_MASK);
        uint16_t selector_leds = selector_leds_from_index(index);
        uint8_t key_pressed = read_key_rising_edge();

        AXI_LW_REG(REG_LEDS) = selector_leds & BITS_LEDS;

        if (key_pressed & KEY0) {
            printf("KEY0 pressed: sw=0x%03X index=%u\n", sw, index);
            if (index <= 5u) {
                hex_state[index] = (uint8_t)(sw & SW_SEG_MASK);
                apply_hex_state(hex_state);
            } else {
                printf("KEY0 ignored: invalid HEX index %u, blinking LED0..2\n", index);
                blink_error_leds(selector_leds);
            }
        }

        if (key_pressed & KEY1) {
            printf("KEY1 pressed: rotate left, index=%u\n", index);
            rotate_left_spec_key1(hex_state);
            apply_hex_state(hex_state);
        }

        if (key_pressed & KEY2) {
            printf("KEY2 pressed: rotate right, index=%u\n", index);
            rotate_right_spec_key2(hex_state);
            apply_hex_state(hex_state);
        }
    }

    return 0;
}
