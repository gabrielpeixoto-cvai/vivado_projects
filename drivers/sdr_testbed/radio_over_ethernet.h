/*
 * radio_over_ethernet.h
 *
 *  Created on: Dec 1, 2015
 *      Author: igorfreire
 */

#ifndef ROE_UTIL_H_
#define ROE_UTIL_H_

#include "xil_types.h"

/************************** Function Prototypes *****************************/
void RoE_initCpri2Ethernet(u8);
void RoE_setCpriControlWord(void);
void RoE_initCpriEmulator(void);
void RoE_configEthFlowControl(u8);
void RoE_disableCpri2Ethernet(void);
void RoE_pollStatus(void);
void RoE_setEthTypeFilters(void);
void RoE_reset(void);

/************************** Variable Definitions ****************************/

extern char AxiEthernetMAC[]; /* Local MAC address */
extern char destMAC[];

#endif /* ROE_UTIL_H_ */
