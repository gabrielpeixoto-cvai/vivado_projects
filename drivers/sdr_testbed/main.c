/***************************** Include Files *********************************/

#include "main.h"
//#include "clock.h"
//#include "radio_over_ethernet.h"
#include "xintc_driver.h"
#include "xil_cache.h"
#include "microblaze_sleep.h"

/************************** Constant Definitions ****************************/

// Interrupts
//#define ROE_INTR_ID	  		  XPAR_MICROBLAZE_0_AXI_INTC_RADIO_OVER_ETHERNET_0_INTERRUPT_INTR
//#define IIC_INTR_ID           XPAR_INTC_0_IIC_0_VEC_ID

//#define FMCOMM_USED  (ROE_CPRI_SRC == ROE_SRC_ADC || ROE_CPRI_SINK == ROE_SINK_DAC)

/************** Conditional Dependencies / Constants ************************/

//#ifndef ROE_BYPASS_FRONTHAUL

//#define AXIETHERNET_DEVICE_ID	XPAR_AXIETHERNET_0_DEVICE_ID
//#define FIFO_DEVICE_ID		XPAR_AXI_FIFO_0_DEVICE_ID

//#include "xaxiethernet_driver.h"
//#include "xllfifo.h"

//#endif

//#if SI_5324
//#include "xiic.h"
//#include "xiic_driver.h"
//extern XIic IicInstance; /* The instance of the IIC device. */
//#endif

//#if SYNC_MODE == PTP
//#include "avb_driver.h"
//#endif

//#if ROE_CPRI_SRC == ROE_SRC_DMA || ROE_CPRI_SINK == ROE_SINK_DMA
#include "dma_driver.h"
//#endif

//#if FMCOMM_USED
#include "ad9361_driver.h"
//#endif

//#if SYNC_MODE == PTP && FMCOMM_USED
//#define PTP_LOCK_ptp_lock_countdown 100
// volatile u32 ptp_lock_countdown = PTP_LOCK_ptp_lock_countdown;
//#else
// volatile u32 ptp_lock_countdown = 0;
//#endif


/************************** Variable Definitions ****************************/

/*
 * Local MAC address
 */
//#if RRU_MODE
//char AxiEthernetMAC[6] = {0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5};
//char destMAC[6] = {0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5};
//#else
//char AxiEthernetMAC[6] = { 0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5 };
//char destMAC[6] = { 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5 };
//#endif

/*
 * IEEE 1588 Port Indentities
 */
//#if SYNC_MODE == PTP
//#if RRU_MODE
//#define ETH_SYSTEM_ADDRESS_EUI48_HIGH  0x000BBB
//#define ETH_SYSTEM_ADDRESS_EUI48_LOW   0x010203
//#else
//#define ETH_SYSTEM_ADDRESS_EUI48_HIGH  0x000A35
//#define ETH_SYSTEM_ADDRESS_EUI48_LOW   0x010203
//#endif
//#endif

//struct clock *clock;
//
//extern void RoE_interruptHandler(void *CallbackRef);
//extern void si5324_interruptHandler(void *CallbackRef);

/************************** Function Prototypes *****************************/

//int initAxiEthernet(u16 AxiEthernetDeviceId, u16 FifoDeviceId);

/*****************************************************************************/
/**
 *
 * Main function for the CPRI emulation test
 *
 ****************************************************************************/
int main(void) {
	int Status;

#if XPAR_MICROBLAZE_USE_ICACHE
	Xil_ICacheInvalidate();
	Xil_ICacheEnable();
#endif

#if XPAR_MICROBLAZE_USE_DCACHE
	Xil_DCacheInvalidate();
	Xil_DCacheEnable();
#endif

	xil_printf("\r\n------ UFA13 - Radio over Ethernet ------r\n");
	xil_printf("Initializing Modules and Peripherals\r\n");

	/*
	 * Init Interrupt Controller
	 */
	Status = initIntc();
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Init AXI Ethernet
	 */
//#ifndef ROE_BYPASS_FRONTHAUL
//	Status = initAxiEthernet(AXIETHERNET_DEVICE_ID, FIFO_DEVICE_ID);
//	if (Status != XST_SUCCESS) {
//		AxiEthernetUtilErrorTrap("Failed test poll mode fifo");
//		return XST_FAILURE;
//	}
//#endif

	/*
	 * Setup interrupts
	 */

//#if SI_5324 == 1
//
//	// Setup the interrupts for the IIC and Si5324
//	if (SetUpInterruptSystem(IIC_INTR_ID,
//			(XInterruptHandler) XIic_InterruptHandler,
//			(void *) &IicInstance) != XST_SUCCESS)
//		return XST_FAILURE;
//
//	/*
//	 * Run the Si5324 IIC configuration.
//	 */
//	Status = initIicEeprom();
//	if (Status != XST_SUCCESS) {
//		return XST_FAILURE;
//	}
//
//	init_clock(clock);
//	// Wait enough for the clock to lock before starting the CPRI emulator
//	MB_Sleep(10000);
//
//#elif ~SI_5324 && RRU_MODE
//	/*
//	 * Init Clock Wizard Configuration
//	 * (Old) Note: do this before initializing the interrupt controller,
//	 * since the ISR requires the global clock struct pointer.
//	 */
//	init_clock(clock);
//#endif

//#if SYNC_MODE == PTP
//	/*
//	 * Init AVB
//	 */
//	Status = initAvb(ETH_SYSTEM_ADDRESS_EUI48_HIGH,
//	ETH_SYSTEM_ADDRESS_EUI48_LOW);
//	if (Status != XST_SUCCESS) {
//		AxiEthernetUtilErrorTrap("Failed to initialize AVB mode");
//		return XST_FAILURE;
//	}
//#endif

//#if (ROE_CPRI_SRC == ROE_SRC_ADC || ROE_CPRI_SINK == ROE_SINK_DAC) && RRU_MODE
//	// Wait for PTP (if being used) to lock before initialize AD9361
//	xil_printf("Waiting PTP to lock...\r\n");
//	while (ptp_lock_countdown != 0) {
//	}
//	xil_printf("\r\n");
//#if SYNC_MODE == PTP
//	// Disable all PTP interrupts while initialize AD9361
//	disableInterrupt(XPAR_INTC_0_AXIETHERNET_0_AV_INTERRUPT_PTP_TX_VEC_ID);
//	disableInterrupt(XPAR_INTC_0_AXIETHERNET_0_AV_INTERRUPT_PTP_RX_VEC_ID);
//	disableInterrupt(XPAR_INTC_0_AXIETHERNET_0_AV_INTERRUPT_10MS_VEC_ID);
//#endif

	Status = initAd9361();
	if (Status != XST_SUCCESS) {
		xil_printf("Failed to initialize AD 9361");
		return XST_FAILURE;
	}

//#if SYNC_MODE == PTP
//	// Re-enable PTP interrupts
//	enableInterrupt(XPAR_INTC_0_AXIETHERNET_0_AV_INTERRUPT_PTP_TX_VEC_ID);
//	enableInterrupt(XPAR_INTC_0_AXIETHERNET_0_AV_INTERRUPT_PTP_RX_VEC_ID);
//	enableInterrupt(XPAR_INTC_0_AXIETHERNET_0_AV_INTERRUPT_10MS_VEC_ID);
//#endif

#endif

//#if ROE_CPRI_SRC == ROE_SRC_DMA || ROE_CPRI_SINK == ROE_SINK_DMA
	Status = initAXIDma();
	if (Status != XST_SUCCESS) {
		xil_printf("Failed to initialize AXI DMA");
		return XST_FAILURE;
	}
//#endif

	/*
	 * Radio over Ethernet Configuration
	 */

	// Reset
	//RoE_reset();

	// Setup RoE Interrupts
//#if SYNC_MODE == BUFFER_BASED
//	if (SetUpInterruptSystem(ROE_INTR_ID,
//			(XInterruptHandler) RoE_interruptHandler, (void *) 0) != XST_SUCCESS)
//		return XST_FAILURE;
//#endif

	// Define the CPRI control word
	//RoE_setCpriControlWord();

//#ifndef ROE_BYPASS_FRONTHAUL
//	// Set EtherType filters for demux
//	//RoE_setEthTypeFilters();
//
//	// Initialize "CPRI to Ethernet" module
//	//RoE_initCpri2Ethernet(ROE_FLOW_CONTROL);
//#endif
//
//#if ROE_CPRI_SRC == ROE_SRC_DMA
//	// Fire a transmission
//	Status = startCyclicDmaRead();
//	if (Status != XST_SUCCESS) {
//		xil_printf("Failed to transmit data via DMA");
//		return XST_FAILURE;
//	}
//#else
//	// Initialize CPRI Emulation:
//	RoE_initCpriEmulator();
//#endif

	// Poll RoE status forever:
	//RoE_pollStatus();

	return XST_SUCCESS;

}
