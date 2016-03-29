
#include "axiEthernet.h"
#include "xaxiethernet.h"
#include "xllfifo.h"
#include <stdio.h>

#if !defined (__MICROBLAZE__) && !defined(__PPC__)
#include "sleep.h"
#endif

void axiEthernet_info(char *STR){
	printf("%s\n", STR);
}

void axiEthernet_error(char *STR){
	printf("%s\n", STR);
}

void AxiEthernetUtilPhyDelay(unsigned int Seconds)
{
#if defined (__MICROBLAZE__) || defined(__PPC__)
	static int WarningFlag = 0;

	/* If MB caches are disabled or do not exist, this delay loop could
	 * take minutes instead of seconds (e.g., 30x longer).  Print a warning
	 * message for the user (once).  If only MB had a built-in timer!
	 */
	if (((mfmsr() & 0x20) == 0) && (!WarningFlag)) {
		WarningFlag = 1;
	}

#define ITERS_PER_SEC   (XPAR_CPU_CORE_CLOCK_FREQ_HZ / 6)
    asm volatile ("\n"
			"1:               \n\t"
			"addik r7, r0, %0 \n\t"
			"2:               \n\t"
			"addik r7, r7, -1 \n\t"
			"bneid  r7, 2b    \n\t"
			"or  r0, r0, r0   \n\t"
			"bneid %1, 1b     \n\t"
			"addik %1, %1, -1 \n\t"
			:: "i"(ITERS_PER_SEC), "d" (Seconds));
#else
    sleep(Seconds);
#endif
}

int axiEthernet_config(
	unsigned short AxiEthernetDeviceId,
	XLlFifo *FifoInstance,
	XAxiEthernet *AxiEthernetInstance,
	unsigned char* EthernetMAC,
	unsigned int FifoBaseAddr
){

	XAxiEthernet_Config *MacCfgPtr;
	int Status;
	int Speed;

	MacCfgPtr = XAxiEthernet_LookupConfig(AxiEthernetDeviceId);
	if(MacCfgPtr == NULL) {
		axiEthernet_error("Unable to load device configurations");
		return -1;
	}
	MacCfgPtr->AxiDevBaseAddress = FifoBaseAddr;

	XLlFifo_Initialize(FifoInstance, MacCfgPtr->AxiDevBaseAddress);

	Status = XAxiEthernet_CfgInitialize(AxiEthernetInstance, MacCfgPtr,
					MacCfgPtr->BaseAddress);
	if (Status != 0) {
		axiEthernet_error("Error initializing Ethernet MAC");
		return -1;
	}

	Status = XAxiEthernet_SetMacAddress(AxiEthernetInstance,
							(unsigned char *) EthernetMAC);
	if (Status != 0) {
		axiEthernet_error("Error setting MAC address");
		return -1;
	}

	if (XAxiEthernet_GetPhysicalInterface(AxiEthernetInstance) ==
							XAE_PHY_TYPE_MII) {
		Speed = 100;
	} else {
		Speed = 1000;
	}

	Status =  XAxiEthernet_SetOperatingSpeed(AxiEthernetInstance,
							(unsigned short) Speed);
	if (Status != 0) {
		return -1;
	}

	XAxiEthernet_ClearBadFrmRcvOption(AxiEthernetInstance);

	/*
	 * Setting the operating speed of the MAC needs a delay.  There
	 * doesn't seem to be register to poll, so please consider this
	 * during your application design.
	 */
	AxiEthernetUtilPhyDelay(2);

	axiEthernet_info("Ethernet configured with Success!");

	return 0;
}

int axiEthernet_start(
	XAxiEthernet *AxiEthernetInstance
){
	XAxiEthernet_Start(AxiEthernetInstance);
}
