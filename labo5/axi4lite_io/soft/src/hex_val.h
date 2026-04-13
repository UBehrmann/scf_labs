/*****************************************************************************************
 * HEIG-VD
 * Haute Ecole d'Ingenerie et de Gestion du Canton de Vaud
 * School of Business and Engineering in Canton de Vaud
 *****************************************************************************************
 * REDS Institute
 * Reconfigurable Embedded Digital Systems
 *****************************************************************************************
 *
 * File                 : hex_val.h
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

#ifndef HEX_VAL_H
#define HEX_VAL_H

#include <stdint.h>

static const uint8_t VAL2SEG[16] = {
    0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07,
    0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71
};

#endif
