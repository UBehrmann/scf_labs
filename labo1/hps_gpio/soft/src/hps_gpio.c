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
 * Author               : 
 * Date                 : 
 *
 * Context              : SCF tutorial lab
 *
 *****************************************************************************************
 * Brief: Blink HPS user LED N times at a given period when HPS user button is pressed.
 *        Uses OSC1 TIMER0 in free-running / polled mode (no interrupts).
 *
 *****************************************************************************************
 * Modifications :
 * Ver    Date        Student      Comments
 * 
 *
*****************************************************************************************/
#include <stdint.h>
#include <stdio.h>

int __auto_semihosting;

/* ---- GPIO ---------------------------------------------------------------- */
#define GPIO_MOD1_BADDR 0xFF709000

#define GPIO_MOD1_PIN_OFFSET -29

#define gpio_swporta_dr_offset   0x00   /* Data register (write to set pin level) */
#define gpio_swporta_ddr_offset  0x04   /* Direction register (1=output, 0=input) */
#define gpio_ext_porta_offset    0x50   /* Read actual pin levels                 */

#define HPS_KEY_GPIO 54
#define HPS_LED_GPIO 53

/* Compute the bit position of a GPIO pin inside the module register */
#define GPIO_BIT(GPIO, OFFSET)  ((unsigned)1 << ((GPIO) + (OFFSET)))
#define HPS_KEY_BIT  (GPIO_BIT(HPS_KEY_GPIO, GPIO_MOD1_PIN_OFFSET))
#define HPS_LED_BIT  (GPIO_BIT(HPS_LED_GPIO, GPIO_MOD1_PIN_OFFSET))

/* Macro to access a memory-mapped register */
#define REG(__x__)  (*((volatile uint32_t *)(__x__)))

/* ---- OSC1 TIMER0 ---------------------------------------------------------
 * Base address : 0xFFD00000  (Cyclone V HPS TRM)
 * Clock        : 25 MHz
 * The counter decrements.  We mask the interrupt (bit 2 of control = 1)
 * so the timer NEVER generates an IRQ -> polled use only.
 * ------------------------------------------------------------------------- */
#define TIMER0_BADDR        0xFFD00000
#define TIMER_LOAD          0x00   /* Load count register                    */
#define TIMER_VALUE         0x04   /* Current value register (read-only)     */
#define TIMER_CONTROL       0x08   /* Control register                       */
                                   /*   bit 0 : enable                       */
                                   /*   bit 1 : mode (0=free-run)            */
                                   /*   bit 2 : interrupt mask (1=no IRQ)    */

#define TIMER_CLK_HZ        25000000   /* 25 MHz */


int main(void)
{
    printf("Labo introduction - Led/Button\n");

    /* Ask the user for blink parameters */
    int nb_blinks;
    int time_ms;

    printf("Nombre de clignotements : \n");
    scanf("%d", &nb_blinks);

    printf("Duree allumee/eteinte (ms) : \n");
    scanf("%d", &time_ms);

    /* ---- GPIO configuration ---------------------------------------------- */
    /* Set LED pin as output (bit = 1) */
    REG(GPIO_MOD1_BADDR + gpio_swporta_ddr_offset) |= HPS_LED_BIT;
    /* Set KEY pin as input (bit = 0) */
    REG(GPIO_MOD1_BADDR + gpio_swporta_ddr_offset) &= ~(uint32_t)HPS_KEY_BIT;

    /* LED off at startup */
    REG(GPIO_MOD1_BADDR + gpio_swporta_dr_offset) &= ~HPS_LED_BIT;

    /* ---- Timer configuration ---------------------------------------------
     * Free-running mode, interrupt masked -> no IRQ generated.
     * The counter starts at 0xFFFFFFFF and counts down at 25 MHz.
     * --------------------------------------------------------------------- */
    REG(TIMER0_BADDR + TIMER_CONTROL) = 0;              /* disable timer first  */
    REG(TIMER0_BADDR + TIMER_LOAD)    = 0xFFFFFFFF;     /* load max value       */
    REG(TIMER0_BADDR + TIMER_CONTROL) = (1 << 0) | (1 << 2); /* enable + mask IRQ */

    printf("Appuyez sur le bouton pour faire clignoter la LED %d fois (%d ms).\n",
           nb_blinks, time_ms);

    /* ---- Main loop ------------------------------------------------------- */
    while (1) {

        /* KEY is active-low: button pressed => bit reads 0 */
        int button_pressed = !(REG(GPIO_MOD1_BADDR + gpio_ext_porta_offset) & HPS_KEY_BIT);

        if (button_pressed) {

            /* Blink the LED nb_blinks times */
            for (int i = 0; i < nb_blinks; i++) {

                /* LED ON */
                REG(GPIO_MOD1_BADDR + gpio_swporta_dr_offset) |= HPS_LED_BIT;

                /* Wait time_ms milliseconds using the timer (polled) */
                uint32_t start  = REG(TIMER0_BADDR + TIMER_VALUE);
                uint32_t cycles = (TIMER_CLK_HZ / 1000) * time_ms;
                /* The counter decrements, so elapsed = start - current */
                while ((start - REG(TIMER0_BADDR + TIMER_VALUE)) < cycles);

                /* LED OFF */
                REG(GPIO_MOD1_BADDR + gpio_swporta_dr_offset) &= ~HPS_LED_BIT;

                /* Wait again */
                start = REG(TIMER0_BADDR + TIMER_VALUE);
                while ((start - REG(TIMER0_BADDR + TIMER_VALUE)) < cycles);
            }

            /* Wait for the button to be released before restarting */
            while (!(REG(GPIO_MOD1_BADDR + gpio_ext_porta_offset) & HPS_KEY_BIT));
        }
    }

    return 0;
}
