#include "xaxiethernet.h"
#include "xllfifo.h"

int axiEthernet_config(
	unsigned short AxiEthernetDeviceId,
	XLlFifo *FifoInstace,
	XAxiEthernet *AxiEthernetInstance,
	unsigned char* EthernetMac,
	unsigned int FifoBaseAddr
);

int axiEthernet_start(
	XAxiEthernet *AxiEthernetInstance
);
