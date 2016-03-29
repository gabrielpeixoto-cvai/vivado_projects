#ifndef XAXIETHERNET_EXAMPLE_H
#define XAXIETHERNET_EXAMPLE_H


/***************************** Include Files *********************************/


#include "xparameters.h"	/* defines XPAR values */
#include "xaxiethernet.h"	/* defines Axi Ethernet APIs */
#include "stdio.h"		/* stdio */

/************************** Constant Definitions ****************************/
#define AXIETHERNET_LOOPBACK_SPEED	100	/* 100Mb/s for Mii */
#define AXIETHERNET_LOOPBACK_SPEED_1G 	1000	/* 1000Mb/s for GMii */
#define AXIETHERNET_PHY_DELAY_SEC	4	/*
						 * Amount of time to delay waiting on
						 * PHY to reset.
						 */

#define MAX_MULTICAST_ADDR   (1<<23)	/*
					 * Maximum number of multicast ethernet
					 * mac addresses.
					 */

/***************** Macros (Inline Functions) Definitions *********************/


/**************************** Type Definitions ******************************/


/************************** Function Prototypes *****************************/

/*
 * Utility functions implemented in xaxiethernet_example_util.c
 */
void AxiEthernetUtilErrorTrap(char *Message);
void AxiEthernetUtilPhyDelay(unsigned int Seconds);
int AxiEthernetUtilConfigureInternalPhy(XAxiEthernet *AxiEthernetInstancePtr,
					int Speed);
int AxiEthernetUtilEnterLoopback(XAxiEthernet * AxiEthernetInstancePtr,
								int Speed);

/************************** Variable Definitions ****************************/

extern char AxiEthernetMAC[];		/* Local MAC address */
extern char destMAC[];
// Define address in the main script

#endif /* XAXIETHERNET_EXAMPLE_H */
