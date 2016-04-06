/*
 * main.h
 *
 *  Created on: Dec 22, 2015
 *      Author: igorfreire
 */

#ifndef CPRI_EMULATION_H_
#define CPRI_EMULATION_H_

#include "roe_bd_configuration.h"
#include "lte_modes.h"

/************************** Constant Definitions ****************************/
/*
 * mode (BBU or RRU) dictates the choice of MAC address and whether clock
 * control is enabled (only for the RRU)
 */
#define RRU_MODE 0
#define LTE_MODE LTE5

#undef DEBUG_OCCUPANCY

/*
 * Enable flow control in the RoE cpri2ethernet module.
 *
 * This is not necessary for any Data Source mode because the implementation
 * restricts the inflow of data in hardware. Use it only for debugging.
*/
#define ROE_FLOW_CONTROL 0


#endif /* CPRI_EMULATION_H_ */
