/*
 * Radio over Ethernet
 *
 *  Created on: Nov 30, 2015
 *      Author: Igor Freire
 *
 */

/***************************** Include Files *********************************/
#include "main.h"
#include "xparameters.h"	/* defines XPAR values */
#include "radio_over_ethernet.h"
#include "xintc_driver.h"
#include "clock.h"
#include "xil_io.h"
#include "microblaze_sleep.h"

/******************* Constant and Parameter Definitions **********************/

/*
 * Available CPRI Line Rates
 */
#define LINE_RATE_OPTION_1 			1
#define LINE_RATE_OPTION_2 			2

/*
 * Enable clock control through polling of occupancy.
 * Otherwise, only interrupts are used to control the clock.
 */
#define POLL_CLK_CONTROL 			1
/*
 * CPRI Line Rate option
 * Currently (for 1G Ethernet), only line rates 1 and 2 are supported
 */
#define LINE_RATE_OPTION 			LINE_RATE_OPTION_1

/*
 * Constants
 */

// RoE Rx Occupancy Interrupt
#define ROE_INTR_ID	  XPAR_MICROBLAZE_0_AXI_INTC_RADIO_OVER_ETHERNET_0_INTERRUPT_INTR

// Packet/Buffer lengths
#define BFs_PER_PKT 				16
#define BUFFER_DEPTH 				8192
#define BUFFER_CENTER				BUFFER_DEPTH/2
#define N_32BIT_WORDS_PER_PKT 		BFs_PER_PKT * (LINE_RATE_OPTION*8*16) / 32

// Thresholds for poll-based control
#define TF0 	N_32BIT_WORDS_PER_PKT
#define TE0 	-N_32BIT_WORDS_PER_PKT

#define CPRI2ETHERNET_ENABLE 	0x00000001
#define FLOW_CONTROL_ENABLE 	0x00000002
#define CPRI_EMULATION_ENABLE   0x00000001

#define CTRL_WORD_MASK 			0xFFFF0000
/*
 * Define the occupancy print intervals in terms of the number of occupancy
 * measurements. When the DMA is used, the DMA interrupts may prevent the
 * polling of the RoE occupancy, so the interval must be shorter.
 */
#if ROE_CPRI_SRC == ROE_SRC_DMA || ROE_CPRI_SINK == ROE_SINK_DMA
#define OCCUPANCY_PRINT_INTERVAL 10000
#else
#define OCCUPANCY_PRINT_INTERVAL 100000
#endif

/************************** Variable Definitions ****************************/

extern struct clock * clock;

volatile static int nFullInterrupts = 0;
volatile static int nEmptyInterrupts = 0;

volatile static u8 correctionFlag = 0;

volatile static u8 roe_started = 0;

#ifdef DEBUG_OCCUPANCY
static u16 i_occ_measure = 0;
#endif

static u32 interruptInfo;
static u8 correctionCode;
static u16 occupancy, transitionCount;

/************************** Function Prototypes *****************************/

void RoE_reset();
void RoE_initCpri2Ethernet(u8);
void RoE_initCpriEmulator();
void RoE_configEthFlowControl(u8);
void RoE_disableCpri2Ethernet();
void RoE_pollStatus();

/*******************************************************************************
 * 	Reset RoE
 *
 * Software reset of the RoE submodules. Resets all of them, except the software
 * interface, where the reset is written.
 *
 ******************************************************************************/
void RoE_reset() {
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x0, 0); //RESET
}

/*******************************************************************************
 * Initialize CPRI to Ethernet module
 *
 * Sets the number of CPRI BFs per Ethernet frame, source and destination MAC
 * addresses, EtherType, defines the operation mode and optionally enables flow
 * control.
 *
 *	Note about flow control:
 *
 * In the cpri2ethernet module, the outgoing Ethernet data is
 * formed in words of 32 bits. For example, one BF of 128 bits
 * takes 4 Ethernet clock (40ns) cycles to be sent for transmission.
 * However, note that the CPRI generation may be slower than
 * the time Ethernet requires for packing. Hence, generally the
 * bottleneck is in the CPRI part. Consider the following example.
 *
 * 	64 BFs per Ethernet Frame
 * 	32 bit IQ samples
 * 	AXI clk -> 100 Mhz
 * 	CPRI clk -> 7.68 Mhz
 *
 * 	One Ethernet packet with 64 BFs takes 4*64
 *  AXI clock cycles to be formed.
 *
 * 	Time to pack Ethernet frame (assuming no overhead):
 * 		4*64*(10 ns) = 256*(10 ns) -> 2.56 us
 *
 * With CPRI emulation, assuming one 64 bit PRBS word is generated at
 * each CPRI clock cycle, with a clock of 7.68Mhz, 128 (2*64) words
 * (of 64 bit) take 2*64*(1/7.68) =  16.6667 us
 *
 * Thus, in this case the bottleneck is in the CPRI emulator, so that
 * flow control is not necessary. However, if a DMA is used to read CPRI
 * data loaded offline, then the bottleneck for speed will be in Etherent
 * itself. In this case, to simulate the "real" CPRI data rate, flow control
 * is necessary.
 *
 ******************************************************************************/

void RoE_initCpri2Ethernet(u8 enFlowControl) {

	u32 mac_addr_reg_0, mac_addr_reg_1, mac_addr_reg_2;
	u32 cpri2ethernetCfg = 0x00000000;

	/*
	 * Define Source and Destination MAC addresses
	 * LSB is the first bit in the MAC address
	 * MSB is the last bit
	 * Example: MAC	ac:87:a3:27:f0:e5
	 * -> Register 05 -> 0x27a387ac
	 * -> Register 06 -> e5f0
	 */
	mac_addr_reg_0 = (((u32) AxiEthernetMAC[3] & 0x000000FF) << 24)
			| (((u32) AxiEthernetMAC[2] & 0x000000FF) << 16)
			| (((u32) AxiEthernetMAC[1] & 0x000000FF) << 8)
			| (((u32) AxiEthernetMAC[0] & 0x000000FF) << 0);

	mac_addr_reg_1 = (((u32) destMAC[3] & 0x000000FF) << 24)
			| (((u32) destMAC[2] & 0x000000FF) << 16)
			| (((u32) destMAC[1] & 0x000000FF) << 8)
			| (((u32) destMAC[0] & 0x000000FF) << 0);

	mac_addr_reg_2 = (((u32) AxiEthernetMAC[5] & 0x000000FF) << 24)
			| (((u32) AxiEthernetMAC[4] & 0x000000FF) << 16)
			| (((u32) destMAC[5] & 0x000000FF) << 8)
			| (((u32) destMAC[4] & 0x000000FF) << 0);

	/*
	 * Number of BFs per Ethernet packet
	 */
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x403, BFs_PER_PKT);

	/*
	 * Source and Destiation MAC Addresses
	 */
	// MACSRC 4 bytes right
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x404, mac_addr_reg_0);
	// MACDEST 4 bytes right
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x405, mac_addr_reg_1);
	// MACSRC 2 bytes right MACDEST 2 bytes right:
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x406, mac_addr_reg_2);

	/*
	 * Ethernet Type
	 */
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x408, 0xCD);

	/*
	 * Operation control (opCtrl)
	 *
	 * 0x9 -> Bit 0 -> Enable cpri2ethernet trasnsmission
	 *        Bit 1 -> Enable Flow Control
	 */
	if (enFlowControl) {

		RoE_configEthFlowControl(BFs_PER_PKT);

		cpri2ethernetCfg |= FLOW_CONTROL_ENABLE;
	}

	cpri2ethernetCfg |= CPRI2ETHERNET_ENABLE; //Enable cpri2eth transmission

	// Configure operation control (opCtrl) of cpri2ethernet module:
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x409, cpri2ethernetCfg);

	// Wait until it is enabled
	while ((Xil_In32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x409)
			& CPRI2ETHERNET_ENABLE) != 1);
}

/*******************************************************************************
 * Disables CPRI to Ethernet module
 *
 ******************************************************************************/
void RoE_disableCpri2Ethernet() {
	xil_printf("\r\nDisabling CPRI");
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x409, 0);
}

/*******************************************************************************
 * Set CPRI Control Word
 *
 * Defines the CPRI control word sent on each BF. Since only line rate options
 * #1 and #2 are supported for compliance to 1000BASE-T, the maximum control
 * word width is 16 bits.
 *
 * The BF control word is within the 16 MSB of the CPRI Source configuration
 * register.
 *
 ******************************************************************************/
void RoE_setCpriControlWord() {

	u16 controlWord;
	u32 temp;

	controlWord = 0x00DE;

	// Read the current value of the CPRI Source configuration register
	temp = Xil_In32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40A);

	// Configure BF control word (16 MSB) and enable CPRI emulation (LSB):
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40A,
			controlWord << 16 | (~CTRL_WORD_MASK & temp));

	temp = Xil_In32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40A);

	xil_printf("\r\n----- Setting CPRI Control Word -----");
	xil_printf("\r\nCPRI Source Reg \t %x", temp);
}

/*******************************************************************************
 * Initialize CPRI Emulator
 *
 * Enables the CPRI Emulator. The enable bit is the LSB of the CPRI Source
 * configuration register.
 *
 ******************************************************************************/
void RoE_initCpriEmulator() {

	u32 temp;

	// Read the current value of the CPRI Source configuration register
	temp = Xil_In32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40A);

	// Configure BF control word (16 MSB) and enable CPRI emulation (LSB):
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40A,
			temp | CPRI_EMULATION_ENABLE);
}

/*******************************************************************************
 * Poll RoE Status
 *
 * CPRI receiver occupancy and words losts in the emulator.
 *
 ******************************************************************************/
void RoE_pollStatus() {

#ifdef DEBUG_OCCUPANCY
	int bfWordsLost;
	int occupancy_offset = 0;
	u16 occupancy;
	int interruptInfo;
#endif

	while (1) {

#if RRU_MODE && SYNC_MODE == BUFFER_BASED // Clock corrections only for RRU mode

#if POLL_CLK_CONTROL
		if (roe_started) {
			if (occupancy_offset > TF0) {
				correctionFlag = 1;
				correctionCode = 5;
				occupancy_offset = 0;
			} else if (occupancy_offset < TE0) {
				correctionFlag = 1;
				correctionCode = 1;
				occupancy_offset = 0;
			}
		}
#endif

		/*
		 *  Clock correction may yield a temporary clock instability (until
		 * lock). This could lead an empty of full buffer, which would cause RoE
		 * to interrupt in panic mode and, ultimately, would prevent further IIC
		 * communication
		 */
		if (correctionFlag) {

			// Correct clock if applicable
			if (correctionCode > 0) {
				if (correctionCode < 4) {
					nEmptyInterrupts++;
					xil_printf("\r\nDecreasing frequency");
					/*
					 * If the buffer is getting empty, decrease the CPRI (read)
					 * clk frequency.
					 */
					adjustFreq(clock, DECREASE_FREQ);
				} else if (correctionCode > 4) {
					nFullInterrupts++;
					/*
					 * If the buffer is getting full, increase the CPRI (read)
					 * clk frequency
					 */
					xil_printf("\r\nIncreasing frequency");
					adjustFreq(clock, INCREASE_FREQ);
				}

#if SI_5324
				// Wait the new clock configuration reach "locked" state
				MB_Sleep(70000);

				// Reset RoE
				RoE_reset();
#endif
			}

			// De-assert the correction flag
			correctionFlag = 0;

			// Re-enable RoE interrupts
			enableInterrupt(ROE_INTR_ID);
		}
#endif

#ifdef DEBUG_OCCUPANCY
		// Print once every second
		if (i_occ_measure++ % OCCUPANCY_PRINT_INTERVAL == 0) {
			bfWordsLost = Xil_In32(
			XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x401);
			interruptInfo = Xil_In32(
			XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40B);
			occupancy = (u16) ((interruptInfo & 0x1FFF0000) >> 16);
			if (occupancy > 0) {
				roe_started = 1;
			}
			occupancy_offset = occupancy - BUFFER_CENTER;

			xil_printf("\r\nBF words lost \t %d \t", bfWordsLost);
			xil_printf("Occupancy \t %d ", occupancy);
			xil_printf("Occ_offset \t %d", occupancy_offset);
		}
#endif

	}
}

/*******************************************************************************
 * Configure cpri2ethernet flow control
 *
 *  Alternate between two inter-departure intervals in order to achieve the
 * target CPRI line rate.
 * 	Since the CPRI BF period is fixed and equal to the chip period of
 * 60.416 us, the number of CPRI BFs per packet define the Ethernet frame
 * inter-departure interval. If this inter-departure is not an integer multiple
 * of the AXI clock, then use the two alternatives to approximate the value on
 * average.
 *
 * Note #1: the following rates are valid assuming a CPRI BF is formed within
 * the number of clock cycles corresponding to the oversampling ratio with
 * respect to the chip rate.
 *
 * Note #2: the maximum supported number of BFs per packet is 93, for line rate
 * option #1. Hence, an uint8 variable is sufficient.
 ******************************************************************************/
void RoE_configEthFlowControl(u8 nBFsPerPkt) {

	xil_printf("\r\n ****** Configuring RoE Flow Control ******  \r\n");

	switch (nBFsPerPkt) {
	case 64:
		xil_printf("\r\n 64 CPRI BFs per Ethernet Frame\r\n");
		Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x407, 0x00000682);
		Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40C, 0x00000683);
		break;

	case 32:
		xil_printf("\r\n 32 CPRI BFs per Ethernet Frame\r\n");
		Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x407, 0x00000342);
		Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40C, 0x00000341);
		break;

	case 16:
		xil_printf("\r\n 16 CPRI BFs per Ethernet Frame\r\n");
		Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x407, 0x000001A0);
		Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40C, 0x000001A1);
		break;

	case 8:
		xil_printf("\r\n 8 CPRI BFs per Ethernet Frame\r\n");
		Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x407, 0x00000209);
		Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40C, 0x00000208);
		break;

	default:
		xil_printf("\r\n Warning: number of BFs not supported. \r\n");
		xil_printf("\r\n 16 CPRI BFs per Ethernet Frame\r\n");
		Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x407, 0x000001A0);
		Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40C, 0x000001A1);
		break;
	}
}

/*******************************************************************************
 *  Set EtherType Filters
 *
 * Configures the EtherTypes used in the AXI Demux module used to demultiplex
 * the data stream received from the external Ethernet MAC.
 *
 ******************************************************************************/
void RoE_setEthTypeFilters() {

	// Configure the demux filter by Ether-type

	// CPRI TRX Stream
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x101, 0xCD);
	// Stream 02 (not used yet)
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x102, 0x00);
	// Metrics Stream
	Xil_Out32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x103, 0x00);

}

/*******************************************************************************
 *
 * Interrupt Service Routine
 *
 * 	Interrupt triggered by the occupancy controller when the occupancy level
 * leaves the "safe zone" around the middlepoint of the buffer. It informs what
 * threshold level the occupancy entered, the actual occupancy and the time
 * taken in the transition from the previous buffer occupancy zone.
 *
 * @param	CallbackRef is passed back to the device driver's interrupt
 *		handler by the XIntc driver.  It was given to the XIntc driver
 *		in the XIntc_Connect() function call.  It is typically a pointer
 *		to the device driver instance variable if using the Xilinx
 *		Level 1 device drivers.  In this example, we do not care about
 *		the callback reference, so we passed it a 0 when connecting the
 *		handler to the XIntc driver and we make no use of it here.
 *
 * @return	None.
 *
 * @note		None.
 *
 ****************************************************************************/

void RoE_interruptHandler(void *CallbackRef) {
	// Read interrupt information
	interruptInfo = Xil_In32(XPAR_RADIO_OVER_ETHERNET_0_BASEADDR + 0x40B);

	correctionCode = (u8) ((interruptInfo & 0xE0000000) >> 29);
	occupancy = (u16) ((interruptInfo & 0x1FFF0000) >> 16);
	transitionCount = (u16) (interruptInfo & 0x0000FFFF);

	// Print
	xil_printf("\r\nCorrection Code: %d", correctionCode);
	xil_printf("\r\nOccupancy: %d \t Transition: %d\r\n", occupancy,
			transitionCount);

	// Flag clock correction
	correctionFlag = 1;
	disableInterrupt(ROE_INTR_ID);
	ackInterrupt(ROE_INTR_ID);
}
