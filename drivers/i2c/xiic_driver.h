/*
 * xiic_driver.h
 *
 *  Created on: Dec 16, 2015
 *      Author: igorfreire
 */

#ifndef XIIC_DRIVER_H_
#define XIIC_DRIVER_H_

/***************************** Include Files *********************************/
#include "xiic.h"

/**************************** Type Definitions *******************************/

/*
 * The AddressType for ML300/ML310 boards should be u16 as the address
 * pointer in the on board EEPROM is 2 bytes.
 * The AddressType for ML403 boards should be u8 as the address pointer in the
 * on board EEPROM is 1 bytes.
 */
typedef u8 AddressType;

/************************** Function Prototypes ******************************/

int initIicEeprom();

int EepromWriteData(u16 ByteCount);

int EepromReadData(u8 *BufferPtr, u16 ByteCount);

int EepromReadData2(AddressType addr, u8 *BufferPtr, u16 ByteCount);

#endif /* XIIC_DRIVER_H_ */
