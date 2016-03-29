/*
 * xintc_driver.h
 *
 *  Created on: Dec 9, 2015
 *      Author: igorfreire
 */

#ifndef XINTC_DRIVER_H_
#define XINTC_DRIVER_H_

/***************************** Include Files *********************************/
#include "xintc.h"

/************************** Function Prototypes *****************************/
int initIntc(void);
int SetUpInterruptSystem(u8 InterruptId, XInterruptHandler handler,
		void *CallBackRef);
int ConnectInterrupt(u8 InterruptId, XInterruptHandler handler,
		void *CallBackRef);
void ackRoeInterrupt(void);
void ackInterrupt(u8 InterruptId);
void disableInterrupt(u8 InterruptId);
void enableInterrupt(u8 InterruptId);
void preventIrqUpTo(u8 InterruptId);
void allowAllIrq(void);

/************************** Variable Definitions ****************************/

#endif /* XINTC_DRIVER_H_ */
