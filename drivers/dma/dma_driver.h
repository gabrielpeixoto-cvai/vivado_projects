/*
 * dma_driver.h
 *
 *  Created on: Feb 16, 2016
 *      Author: igorfreire
 */

#ifndef DMA_DRIVER_H_
#define DMA_DRIVER_H_

#include "xaxidma.h"

int initAXIDma(void);
int loadRndCriDataIntoMemory(XAxiDma *);
int transmitRndCpriData(void);
int startCyclicDmaRead(void);

#endif /* DMA_DRIVER_H_ */
