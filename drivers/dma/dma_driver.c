/*
 * dma.c
 *
 *  Created on: Feb 16, 2016
 *      Author: igorfreire
 *
 *
 * Two functions are available for random data transmission:
 *      - transmitRndCpriData()
 *      - startCyclicDmaRead()
 *
 * The former is used to transmit using interrupts in normal mode, while the
 * latter is used to transmit in cyclic mode. The user should control the mode
 * of transmission by the TRANSMIT_IN_CYCLIC_MODE definition. In addition, one
 * of the two should be used in the main script. When "transmitRndCpriData()" is
 * the one added in the main script, the first transmission will lead to an
 * interrupt, whose callback will trigger another call of
 * "transmitRndCpriData()". In contrast, when "startCyclicDmaRead()" is the one
 * included in the main script, it suffices to fire it once, since no interrupt
 * will be generated for completed transmission when the cyclic mode is used.
 *
 * Regarding the Tx data, either random and preset data can be transmitted. The
 * user has to configure using the "LOAD_TX_WAVEFORM" definition. When using a
 * preset waveform (LOAD_TX_WAVEFORM defined), the waveform has to obey a few
 * rules:
 *  - It must be provided as an array "u32 txWaveform[N_TX_IQ_SAMPLES]={};".
 *    In another words, it must be name "txWaveform" and be of type u32.
 *  - The number of IQ samples in the array must be provided in a definition
 *    named "N_TX_IQ_SAMPLES".
 *  - It must be generated considering the IQ sample size used in the hardware
 *    and the corresponding truncation. For example, when the IQ sample size is
 *    30, the CPRI packer module will truncate by throwing away the LSB of each
 * 	  16 bit word representing I and Q. Therefore, in this case IQ samples in
 *    the waveform should be generated using a mask of "0xFFFEFFFE".
 */

/***************************** Include Files *********************************/

#include "xparameters.h"
#include "main.h"
#include "xintc_driver.h"
#include "xaxidma.h"
#include "xil_io.h"

/************************** Constant Definitions *****************************/

/*
 * Define the mode of transmission by defining or undefining the following:
 */
#define TRANSMIT_IN_CYCLIC_MODE
/*
 * Define whether a preset transmit waveform should be loaded
 */
#undef LOAD_TX_WAVEFORM

// Include the desired waveform
//#ifdef LOAD_TX_WAVEFORM
//#if LTE_MODE == LTE5
#include "waveforms/lte_5Mhz.h"
//#else
//#include "waveforms/txWaveform.h"
//#endif
//#endif

//#if ROE_CPRI_SRC == ROE_SRC_DMA
#define DMA_TX_INTR_ID        XPAR_MICROBLAZE_0_AXI_INTC_AD9361_DMA_MM2S_INTROUT_INTR//XPAR_MICROBLAZE_0_AXI_INTC_AXI_DMA_0_MM2S_INTROUT_INTR
//#endif

//#if ROE_CPRI_SINK == ROE_SINK_DMA
//#define DMA_RX_INTR_ID        XPAR_MICROBLAZE_0_AXI_INTC_AXI_DMA_0_S2MM_INTROUT_INTR
//#endif

#define DMA_DEV_ID		XPAR_AD9361_DMA_DEVICE_ID//XPAR_AXIDMA_0_DEVICE_ID
#define DDR_BASE_ADDR	XPAR_MIG7SERIES_0_BASEADDR

/*
 * CAUTION
 *
 * Be careful about the following definitions, which determine the addresses
 * where BD rings are allocated and where the Transmit Buffer (vector of IQ
 * samples) is allocated. Memory regions used by other applications could be
 * overwritten, depending on the linker configuration.
 *
 * The following addresses were tested using:
 *  _STACK_SIZE : 0x40000;
 *  _HEAP_SIZE  : 0x40000;
 */
#define MEM_BASE_ADDR		(DDR_BASE_ADDR + 0x1000000)

#define RX_BD_SPACE_BASE	(MEM_BASE_ADDR)
#define RX_BD_SPACE_HIGH	(MEM_BASE_ADDR + 0x0000FFFF)
#define TX_BD_SPACE_BASE	(MEM_BASE_ADDR + 0x00010000)
#define TX_BD_SPACE_HIGH	(MEM_BASE_ADDR + 0x0001FFFF)
#define TX_BUFFER_BASE		(MEM_BASE_ADDR + 0x00100000)
#define RX_BUFFER_BASE		(MEM_BASE_ADDR + 0x00300000)
#define RX_BUFFER_HIGH		(MEM_BASE_ADDR + 0x004FFFFF)

/*
 * Timeout loop counter for reset
 * (only for the regular transmission mode)
 */
#define RESET_TIMEOUT_COUNTER	10000

/*
 * For Random IQ Data Generation
 * (valid only for the regular transmission mode and when random data is
 * generated, instead of read from an external header)
 */
//#ifndef LOAD_TX_WAVEFORM
#define N_IQ_SAMPLES		    375 * 2048
//#else
//#define N_IQ_SAMPLES N_TX_IQ_SAMPLES
//#endif

/*
 * Number of IQ samples processed per DMA read transaction.
 * Note: this is the number of IQ samples expected in the cyclic mode. Since in
 * this mode only one BD is used, a single DMA read transaction is continuously
 * repeated. If a preset (external) transmit waveform is used, it has to define
 * "N_TX_IQ_SAMPLES" as the number of samples in the preset array.
 */
//#ifndef LOAD_TX_WAVEFORM
//#define N_IQs_PER_DMA_READ		75 * 2048
//#else
#define N_IQs_PER_DMA_READ		N_TX_IQ_SAMPLES
//#endif
// DMA Engine requires the number of bytes (4 per IQ sample):
#define BYTES_PER_DMA_READ		N_IQs_PER_DMA_READ * 4

/*
 * Number of BDs per transmission in regular mode
 * (in cyclic mode only one is used)
 */
#define NUMBER_OF_BDS_PER_TX		10

/* The interrupt coalescing threshold and delay timer threshold
 * Valid range is 1 to 255
 *
 * We set the coalescing threshold to be the total number of packets.
 * The receive side will only get one completion interrupt for this example.
 */
#define COALESCING_COUNT		NUMBER_OF_BDS_PER_TX
#define DELAY_TIMER_COUNT		100

/*
 * Buffer and Buffer Descriptor related constant definition
 */
#define N_DMA_READ_BURSTS  16
#define MAX_PKT_LEN		BYTES_PER_DMA_READ / N_DMA_READ_BURSTS

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

static void TxIntrHandler(void *Callback);
static void RxIntrHandler(void *Callback);
static void TxCallBack(XAxiDma_BdRing * TxRingPtr);
static void RxCallBack(XAxiDma_BdRing * RxRingPtr);
static int RxSetup(XAxiDma * AxiDmaInstPtr);
static int TxSetup(XAxiDma * AxiDmaInstPtr);
static int SendPacket(XAxiDma * AxiDmaInstPtr);

/************************** Variable Definitions *****************************/

static XAxiDma AxiDma; /* Instance of the XAxiDma */

/*
 * Flags interrupt handlers use to notify the application context the events.
 */
volatile int TxDone;
volatile int RxDone;
volatile int Error;

/*****************************************************************************/

/*****************************************************************************/
/*
 *
 * DMA Initialization
 *
 ******************************************************************************/
int initAXIDma(void) {
	int Status;
	XAxiDma_Config *Config;

	xil_printf("\r\n--- Initializing AXI DMA --- \r\n");

	Config = XAxiDma_LookupConfig(DMA_DEV_ID);
	if (!Config) {
		xil_printf("No config found for %d\r\n", DMA_DEV_ID);

		return XST_FAILURE;
	}

	/* Initialize DMA engine */
	Status = XAxiDma_CfgInitialize(&AxiDma, Config);

	if (Status != XST_SUCCESS) {
		xil_printf("Initialization failed %d\r\n", Status);
		return XST_FAILURE;
	}

	if (!XAxiDma_HasSg(&AxiDma)) {
		xil_printf("Device configured as Simple mode \r\n");
		return XST_FAILURE;
	}

	/* Set up TX/RX channels to be ready to transmit and receive packets */
#if ROE_CPRI_SRC == ROE_SRC_DMA
	Status = TxSetup(&AxiDma);

	if (Status != XST_SUCCESS) {

		xil_printf("Failed TX setup\r\n");
		return XST_FAILURE;
	}

	if (Config->HasMm2S) {
		// Setup the AXI DMA interrupts
		if (SetUpInterruptSystem(DMA_TX_INTR_ID,
				(XInterruptHandler) TxIntrHandler,
				(void *) &AxiDma) != XST_SUCCESS)
			return XST_FAILURE;
	}
#endif

//#if ROE_CPRI_SINK == ROE_SINK_DMA
//	Status = RxSetup(&AxiDma);
//	if (Status != XST_SUCCESS) {
//
//		xil_printf("Failed RX setup\r\n");
//		return XST_FAILURE;
//	}
//	if (Config->HasS2Mm) {
//		if (SetUpInterruptSystem(DMA_RX_INTR_ID,
//						(XInterruptHandler) RxIntrHandler,
//						(void *) &AxiDma) != XST_SUCCESS)
//		return XST_FAILURE;
//	}
//#endif

	/* Disable all interrupts before setup */
	XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

	XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

	/* Enable all required interrupts */
#ifdef TRANSMIT_IN_CYCLIC_MODE
	// When transmitting in Cyclic mode, Tx Complete interrupts are disabled.
	XAxiDma_IntrEnable(&AxiDma,
			(XAXIDMA_IRQ_ERROR_MASK | XAXIDMA_IRQ_DELAY_MASK),
			XAXIDMA_DMA_TO_DEVICE);
#else
	// When not in Cyclic mode, all interrupts are enabled
	XAxiDma_IntrEnable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
#endif

	XAxiDma_IntrEnable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

	return XST_SUCCESS;
}

/*****************************************************************************/
/*
 *
 * To load random CPRI data into the memory
 *
 ******************************************************************************/

int loadRndCriDataIntoMemory(XAxiDma * AxiDmaInstPtr) {
	XAxiDma_BdRing *TxRingPtr = XAxiDma_GetTxRing(AxiDmaInstPtr);
	u8 *TxBufferPtr;
	u8 Value;
	int iIqSample;
	int iWordByte;
	TxBufferPtr = (u8 *) TX_BUFFER_BASE;

	/*
	 * Each packet is limited to TxRingPtr->MaxTransferLen
	 *
	 * This will not be the case if hardware has store and forward built in
	 */
	if (MAX_PKT_LEN * NUMBER_OF_BDS_PER_TX > TxRingPtr->MaxTransferLen) {

		xil_printf("Invalid total per packet transfer length for the "
				"packet %d/%d\r\n",
		MAX_PKT_LEN * NUMBER_OF_BDS_PER_TX, TxRingPtr->MaxTransferLen);

		return XST_INVALID_PARAM;
	}

	Value = 0;

	// Load data
	for (iIqSample = 0; iIqSample < N_IQ_SAMPLES; iIqSample++) {
		// Iterate over the bytes in each 32-bit word
		for (iWordByte = 0; iWordByte < 4; iWordByte++) {

			TxBufferPtr[(iIqSample * 4) + iWordByte] = Value;
		}
		Value = (Value + 1) & 0xFF;
	}

	xil_printf("\r\n Random CPRI Data Loaded into Memory \r\n");

	return XST_SUCCESS;
}

int transmitRndCpriData(void) {

	int Status;

	/* Send a packet */
	Status = SendPacket(&AxiDma);
	if (Status != XST_SUCCESS) {

		xil_printf("Failed send packet\r\n");
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}

/*****************************************************************************/
/*
 *
 * This function sets up RX channel of the DMA engine to be ready for packet
 * reception
 *
 * @param	AxiDmaInstPtr is the pointer to the instance of the DMA engine.
 *
 * @return	- XST_SUCCESS if the setup is successful.
 *		- XST_FAILURE if fails.
 *
 * @note		None.
 *
 ******************************************************************************/
static int RxSetup(XAxiDma * AxiDmaInstPtr) {
	XAxiDma_BdRing *RxRingPtr;
	int Status;
	XAxiDma_Bd BdTemplate;
	XAxiDma_Bd *BdPtr;
	XAxiDma_Bd *BdCurPtr;
	int BdCount;
	int FreeBdCount;
	u32 RxBufferPtr;
	int Index;

	RxRingPtr = XAxiDma_GetRxRing(&AxiDma);

	/* Disable all RX interrupts before RxBD space setup */
	XAxiDma_BdRingIntDisable(RxRingPtr, XAXIDMA_IRQ_ALL_MASK);

	/* Setup Rx BD space */
	BdCount = XAxiDma_BdRingCntCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT,
			RX_BD_SPACE_HIGH - RX_BD_SPACE_BASE + 1);

	Status = XAxiDma_BdRingCreate(RxRingPtr, RX_BD_SPACE_BASE,
	RX_BD_SPACE_BASE,
	XAXIDMA_BD_MINIMUM_ALIGNMENT, BdCount);
	if (Status != XST_SUCCESS) {
		xil_printf("Rx bd create failed with %d\r\n", Status);
		return XST_FAILURE;
	}

	/*
	 * Setup a BD template for the Rx channel. Then copy it to every RX BD.
	 */
	XAxiDma_BdClear(&BdTemplate);
	Status = XAxiDma_BdRingClone(RxRingPtr, &BdTemplate);
	if (Status != XST_SUCCESS) {
		xil_printf("Rx bd clone failed with %d\r\n", Status);
		return XST_FAILURE;
	}

	/* Attach buffers to RxBD ring so we are ready to receive packets */
	FreeBdCount = XAxiDma_BdRingGetFreeCnt(RxRingPtr);

	Status = XAxiDma_BdRingAlloc(RxRingPtr, FreeBdCount, &BdPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("Rx bd alloc failed with %d\r\n", Status);
		return XST_FAILURE;
	}

	BdCurPtr = BdPtr;
	RxBufferPtr = RX_BUFFER_BASE;

	for (Index = 0; Index < FreeBdCount; Index++) {

		Status = XAxiDma_BdSetBufAddr(BdCurPtr, RxBufferPtr);
		if (Status != XST_SUCCESS) {
			xil_printf("Rx set buffer addr %x on BD %x failed %d\r\n",
					(unsigned int) RxBufferPtr, (unsigned int) BdCurPtr,
					Status);

			return XST_FAILURE;
		}

		Status = XAxiDma_BdSetLength(BdCurPtr, MAX_PKT_LEN,
				RxRingPtr->MaxTransferLen);
		if (Status != XST_SUCCESS) {
			xil_printf("Rx set length %d on BD %x failed %d\r\n",
			MAX_PKT_LEN, (unsigned int) BdCurPtr, Status);

			return XST_FAILURE;
		}

		/* Receive BDs do not need to set anything for the control
		 * The hardware will set the SOF/EOF bits per stream status
		 */
		XAxiDma_BdSetCtrl(BdCurPtr, 0);

		XAxiDma_BdSetId(BdCurPtr, RxBufferPtr);

		RxBufferPtr += MAX_PKT_LEN;
		BdCurPtr = XAxiDma_BdRingNext(RxRingPtr, BdCurPtr);
	}

	/*
	 * Set the coalescing threshold, so only one receive interrupt
	 * occurs for this example
	 *
	 * If you would like to have multiple interrupts to happen, change
	 * the COALESCING_COUNT to be a smaller value
	 */
	Status = XAxiDma_BdRingSetCoalesce(RxRingPtr, COALESCING_COUNT,
	DELAY_TIMER_COUNT);
	if (Status != XST_SUCCESS) {
		xil_printf("Rx set coalesce failed with %d\r\n", Status);
		return XST_FAILURE;
	}

	Status = XAxiDma_BdRingToHw(RxRingPtr, FreeBdCount, BdPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("Rx ToHw failed with %d\r\n", Status);
		return XST_FAILURE;
	}

	/* Enable all RX interrupts */
	XAxiDma_BdRingIntEnable(RxRingPtr, XAXIDMA_IRQ_ALL_MASK);

	/* Start RX DMA channel */
	Status = XAxiDma_BdRingStart(RxRingPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("Rx start BD ring failed with %d\r\n", Status);
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}

/*****************************************************************************/
/*
 *
 * This function sets up the TX channel of a DMA engine to be ready for packet
 * transmission.
 *
 * @param	AxiDmaInstPtr is the pointer to the instance of the DMA engine.
 *
 * @return	- XST_SUCCESS if the setup is successful.
 *		- XST_FAILURE otherwise.
 *
 * @note		None.
 *
 ******************************************************************************/
static int TxSetup(XAxiDma * AxiDmaInstPtr) {
	XAxiDma_BdRing *TxRingPtr = XAxiDma_GetTxRing(&AxiDma);
	XAxiDma_Bd BdTemplate;
	int Status;
	u32 BdCount;

	// Load Random CPRI data into Memory:
	Status = loadRndCriDataIntoMemory(&AxiDma);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed to load data into memory\r\n");
		return XST_FAILURE;
	}

	/* Disable all TX interrupts before TxBD space setup */
	XAxiDma_BdRingIntDisable(TxRingPtr, XAXIDMA_IRQ_ALL_MASK);

	/* Setup TxBD space  */
	BdCount = XAxiDma_BdRingCntCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT,
			(u32)TX_BD_SPACE_HIGH - (u32)TX_BD_SPACE_BASE + 1);

	Status = XAxiDma_BdRingCreate(TxRingPtr, TX_BD_SPACE_BASE,
	TX_BD_SPACE_BASE,
	XAXIDMA_BD_MINIMUM_ALIGNMENT, BdCount);
	if (Status != XST_SUCCESS) {

		xil_printf("Failed create BD ring\r\n");
		return XST_FAILURE;
	}

	/*
	 * Like the RxBD space, we create a template and set all BDs to be the
	 * same as the template. The sender has to set up the BDs as needed.
	 */
	XAxiDma_BdClear(&BdTemplate);
	Status = XAxiDma_BdRingClone(TxRingPtr, &BdTemplate);
	if (Status != XST_SUCCESS) {

		xil_printf("Failed clone BDs\r\n");
		return XST_FAILURE;
	}

#ifndef TRANSMIT_IN_CYCLIC_MODE
	/*
	 * Set the coalescing threshold, so only one transmit interrupt
	 * occurs for this example
	 *
	 * If you would like to have multiple interrupts to happen, change
	 * the COALESCING_COUNT to be a smaller value
	 */
	Status = XAxiDma_BdRingSetCoalesce(TxRingPtr, COALESCING_COUNT,
			DELAY_TIMER_COUNT);
	if (Status != XST_SUCCESS) {

		xil_printf("Failed set coalescing"
				" %d/%d\r\n", COALESCING_COUNT, DELAY_TIMER_COUNT);
		return XST_FAILURE;
	}

	/* Enable all TX interrupts */
	XAxiDma_BdRingIntEnable(TxRingPtr, XAXIDMA_IRQ_ALL_MASK);

	/* Start the TX channel */
	Status = XAxiDma_BdRingStart(TxRingPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed bd start\r\n");
		return XST_FAILURE;
	}
#endif

	return XST_SUCCESS;
}

/*****************************************************************************/
/*
 *
 * This is the DMA TX callback function to be called by TX interrupt handler.
 * This function handles BDs finished by hardware.
 *
 * @param	TxRingPtr is a pointer to TX channel of the DMA engine.
 *
 * @return	None.
 *
 * @note		None.
 *
 ******************************************************************************/
static void TxCallBack(XAxiDma_BdRing * TxRingPtr) {
	int BdCount;
	u32 BdSts;
	XAxiDma_Bd *BdPtr;
	XAxiDma_Bd *BdCurPtr;
	int Status;
	int Index;

	/* Get all processed BDs from hardware */
	BdCount = XAxiDma_BdRingFromHw(TxRingPtr, XAXIDMA_ALL_BDS, &BdPtr);

	/* Handle the BDs */
	BdCurPtr = BdPtr;
	for (Index = 0; Index < BdCount; Index++) {

		/*
		 * Check the status in each BD
		 * If error happens, the DMA engine will be halted after this
		 * BD processing stops.
		 */
		BdSts = XAxiDma_BdGetSts(BdCurPtr);
		if ((BdSts & XAXIDMA_BD_STS_ALL_ERR_MASK)
				|| (!(BdSts & XAXIDMA_BD_STS_COMPLETE_MASK))) {

			Status = XST_FAILURE;
			break;
		}

		/*
		 * Here we don't need to do anything. But if a RTOS is being
		 * used, we may need to free the packet buffer attached to
		 * the processed BD
		 */

		/* Find the next processed BD */
		BdCurPtr = XAxiDma_BdRingNext(TxRingPtr, BdCurPtr);
	}

	/* Free all processed BDs for future transmission */
	Status = XAxiDma_BdRingFree(TxRingPtr, BdCount, BdPtr);
	if (Status != XST_SUCCESS) {
		Error = 1;
	} else {
		TxDone += BdCount;

		Status = SendPacket(&AxiDma);
		if (Status != XST_SUCCESS) {
			Error = 1;
			xil_printf("Failed send packet\r\n");
		}
	}
}

/*****************************************************************************/
/*
 *
 * This is the DMA TX Interrupt handler function.
 *
 * It gets the interrupt status from the hardware, acknowledges it, and if any
 * error happens, it resets the hardware. Otherwise, if a completion interrupt
 * is present, then sets the TxDone.flag
 *
 * @param	Callback is a pointer to TX channel of the DMA engine.
 *
 * @return	None.
 *
 * @note		None.
 *
 ******************************************************************************/
static void TxIntrHandler(void *Callback) {
	XAxiDma_BdRing *TxRingPtr = XAxiDma_GetTxRing((XAxiDma * ) Callback);
	u32 IrqStatus;
	int TimeOut;

	/*
	 * Since the DMA as Tx (Read Channel) has to have highest priority
	 * (interrupt 0) and can't be preempted, disable all lower priority
	 * interrupts (starting from interrupt 1).
	 */
	preventIrqUpTo(1);

	/* Read pending interrupts */
	IrqStatus = XAxiDma_BdRingGetIrq(TxRingPtr);

	/* Acknowledge pending interrupts */
	XAxiDma_BdRingAckIrq(TxRingPtr, IrqStatus);

	/* If no interrupt is asserted, we do not do anything
	 */
	if (!(IrqStatus & XAXIDMA_IRQ_ALL_MASK)) {
		allowAllIrq();
		return;
	}

	/*
	 * If error interrupt is asserted, raise error flag, reset the
	 * hardware to recover from the error, and return with no further
	 * processing.
	 */
	if ((IrqStatus & XAXIDMA_IRQ_ERROR_MASK)) {

		XAxiDma_BdRingDumpRegs(TxRingPtr);

		Error = 1;

		/*
		 * Reset should never fail for transmit channel
		 */
		XAxiDma_Reset(&AxiDma);

		TimeOut = RESET_TIMEOUT_COUNTER;

		while (TimeOut) {
			if (XAxiDma_ResetIsDone(&AxiDma)) {
				break;
			}

			TimeOut -= 1;
		}

		allowAllIrq();
		return;
	}

	/*
	 * If Transmit done interrupt is asserted, call TX call back function
	 * to handle the processed BDs and raise the according flag
	 */
	if ((IrqStatus & (XAXIDMA_IRQ_DELAY_MASK | XAXIDMA_IRQ_IOC_MASK))) {
		TxCallBack(TxRingPtr);
	}

	allowAllIrq();

}

/*****************************************************************************/
/*
 *
 * This is the DMA RX callback function called by the RX interrupt handler.
 * This function handles finished BDs by hardware, attaches new buffers to those
 * BDs, and give them back to hardware to receive more incoming packets
 *
 * @param	RxRingPtr is a pointer to RX channel of the DMA engine.
 *
 * @return	None.
 *
 * @note		None.
 *
 ******************************************************************************/
static void RxCallBack(XAxiDma_BdRing * RxRingPtr) {
	int BdCount;
	XAxiDma_Bd *BdPtr;
	XAxiDma_Bd *BdCurPtr;
	u32 BdSts;
	int Index;

	/* Get finished BDs from hardware */
	BdCount = XAxiDma_BdRingFromHw(RxRingPtr, XAXIDMA_ALL_BDS, &BdPtr);

	BdCurPtr = BdPtr;
	for (Index = 0; Index < BdCount; Index++) {

		/*
		 * Check the flags set by the hardware for status
		 * If error happens, processing stops, because the DMA engine
		 * is halted after this BD.
		 */
		BdSts = XAxiDma_BdGetSts(BdCurPtr);
		if ((BdSts & XAXIDMA_BD_STS_ALL_ERR_MASK)
				|| (!(BdSts & XAXIDMA_BD_STS_COMPLETE_MASK))) {
			Error = 1;
			break;
		}

		/* Find the next processed BD */
		BdCurPtr = XAxiDma_BdRingNext(RxRingPtr, BdCurPtr);
		RxDone += 1;
	}

}

/*****************************************************************************/
/*
 *
 * This is the DMA RX interrupt handler function
 *
 * It gets the interrupt status from the hardware, acknowledges it, and if any
 * error happens, it resets the hardware. Otherwise, if a completion interrupt
 * presents, then it calls the callback function.
 *
 * @param	Callback is a pointer to RX channel of the DMA engine.
 *
 * @return	None.
 *
 * @note		None.
 *
 ******************************************************************************/
static void RxIntrHandler(void *Callback) {
	XAxiDma_BdRing *RxRingPtr = XAxiDma_GetRxRing((XAxiDma * ) Callback);

	u32 IrqStatus;
	int TimeOut;

	/* Read pending interrupts */
	IrqStatus = XAxiDma_BdRingGetIrq(RxRingPtr);

	/* Acknowledge pending interrupts */
	XAxiDma_BdRingAckIrq(RxRingPtr, IrqStatus);

	/*
	 * If no interrupt is asserted, we do not do anything
	 */
	if (!(IrqStatus & XAXIDMA_IRQ_ALL_MASK)) {
		return;
	}

	/*
	 * If error interrupt is asserted, raise error flag, reset the
	 * hardware to recover from the error, and return with no further
	 * processing.
	 */
	if ((IrqStatus & XAXIDMA_IRQ_ERROR_MASK)) {

		XAxiDma_BdRingDumpRegs(RxRingPtr);

		Error = 1;

		/* Reset could fail and hang
		 * NEED a way to handle this or do not call it??
		 */
		XAxiDma_Reset(&AxiDma);

		TimeOut = RESET_TIMEOUT_COUNTER;

		while (TimeOut) {
			if (XAxiDma_ResetIsDone(&AxiDma)) {
				break;
			}

			TimeOut -= 1;
		}

		return;
	}

	/*
	 * If completion interrupt is asserted, call RX call back function
	 * to handle the processed BDs and then raise the according flag.
	 */
	if ((IrqStatus & (XAXIDMA_IRQ_DELAY_MASK | XAXIDMA_IRQ_IOC_MASK))) {
		RxCallBack(RxRingPtr);
	}
}

/*****************************************************************************/
/*
 *
 * This function non-blockingly transmits all packets through the DMA engine.
 *
 * @param	AxiDmaInstPtr points to the DMA engine instance
 *
 * @return
 * 		- XST_SUCCESS if the DMA accepts all the packets successfully,
 * 		- XST_FAILURE if error occurs
 *
 * @note		None.
 *
 ******************************************************************************/
static int SendPacket(XAxiDma * AxiDmaInstPtr) {
	XAxiDma_BdRing *TxRingPtr = XAxiDma_GetTxRing(AxiDmaInstPtr);
	u8 *TxPacket;
	XAxiDma_Bd *BdPtr, *BdCurPtr;
	int Status;
	int Pkts;
	u32 BufferAddr;

	TxPacket = (u8 *) TX_BUFFER_BASE;

	/* Flush the SrcBuffer before the DMA transfer, in case the Data Cache
	 * is enabled
	 */
	Xil_DCacheFlushRange((u32 )TxPacket, MAX_PKT_LEN * NUMBER_OF_BDS_PER_TX);

	Status = XAxiDma_BdRingAlloc(TxRingPtr, NUMBER_OF_BDS_PER_TX, &BdPtr);
	if (Status != XST_SUCCESS) {

		xil_printf("Failed bd alloc \t STATUS \t %d \r\n", Status);
		return XST_FAILURE;
	}

	BufferAddr = (u32) TX_BUFFER_BASE;
	BdCurPtr = BdPtr;

	/*
	 * Set up the BD using the information of the packet to transmit
	 * Each transmission has NUMBER_OF_BDS_PER_TX BDs
	 */

	for (Pkts = 0; Pkts < NUMBER_OF_BDS_PER_TX; Pkts++) {
		u32 CrBits = 0;

		Status = XAxiDma_BdSetBufAddr(BdCurPtr, BufferAddr);
		if (Status != XST_SUCCESS) {
			xil_printf("Tx set buffer addr %x on BD %x failed %d\r\n",
					(unsigned int) BufferAddr, (unsigned int) BdCurPtr, Status);

			return XST_FAILURE;
		}

		Status = XAxiDma_BdSetLength(BdCurPtr, MAX_PKT_LEN,
				TxRingPtr->MaxTransferLen);
		if (Status != XST_SUCCESS) {
			xil_printf("Tx set length %d on BD %x failed %d\r\n",
			MAX_PKT_LEN, (unsigned int) BdCurPtr, Status);

			return XST_FAILURE;
		}

		if (Pkts == 0) {
			/* The first BD has SOF set
			 */
			CrBits |= XAXIDMA_BD_CTRL_TXSOF_MASK;
		}

		if (Pkts == (NUMBER_OF_BDS_PER_TX - 1)) {
			/* The last BD should have EOF and IOC set
			 */
			CrBits |= XAXIDMA_BD_CTRL_TXEOF_MASK;

		}

		XAxiDma_BdSetCtrl(BdCurPtr, CrBits);
		XAxiDma_BdSetId(BdCurPtr, BufferAddr);

		BufferAddr += MAX_PKT_LEN;
		BdCurPtr = XAxiDma_BdRingNext(TxRingPtr, BdCurPtr);

	}

	/* Give the BD to hardware */
	Status = XAxiDma_BdRingToHw(TxRingPtr, NUMBER_OF_BDS_PER_TX, BdPtr);
	if (Status != XST_SUCCESS) {

		xil_printf("Failed to hw, length %d\r\n",
				(int) XAxiDma_BdGetLength(BdPtr, TxRingPtr->MaxTransferLen));

		return XST_FAILURE;
	}

	return XST_SUCCESS;
}

/*****************************************************************************/
/*
 *
 * Transmits all packets through the DMA engine in cyclic mode, i.e. without
 * interrupting the processor.
 *
 * @param	AxiDmaInstPtr points to the DMA engine instance
 *
 * @return
 * 		- XST_SUCCESS if the DMA accepts all the packets successfully,
 * 		- XST_FAILURE if error occurs
 *
 * @note		None.
 *
 ******************************************************************************/
int startCyclicDmaRead() {
	XAxiDma_BdRing *TxRingPtr = XAxiDma_GetTxRing(&AxiDma);
	XAxiDma_Bd *BdPtr;
	int Status;
	u32 BufferAddr;
#if 1
	BufferAddr = (u32) &txWaveform;
#endif

#if 0
	BufferAddr = (u32) TX_BUFFER_BASE;
#endif

	/*
	 * Set cyclic mode for the read channel
	 */
	if (XAxiDma_SelectCyclicMode(&AxiDma, XAXIDMA_DMA_TO_DEVICE,
	TRUE) != XST_SUCCESS) {
		xil_printf("Problem setting to cyclic mode\r\n");
		return XST_FAILURE;
	}

	/*
	 * Allocate, setup, and enqueue 1 TxBD. The BD points to itself, so
	 * it is cyclicly used for triggering DMA reads.
	 */
	Status = XAxiDma_BdRingAlloc(TxRingPtr, 1, &BdPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("Error allocating TxBD");
		return XST_FAILURE;
	}

	/*
	 * Setup TxBD #1
	 */
	XAxiDma_BdSetBufAddr(BdPtr, BufferAddr);
	// Read the entire buffer at once
	XAxiDma_BdSetLength(BdPtr, BYTES_PER_DMA_READ, TxRingPtr->MaxTransferLen);
	// At the same BD, mark both SOF and EOF
	XAxiDma_BdSetCtrl(BdPtr,
	XAXIDMA_BD_CTRL_TXEOF_MASK | XAXIDMA_BD_CTRL_TXSOF_MASK);

	/*
	 * Enqueue to HW
	 */
	Status = XAxiDma_BdRingToHw(TxRingPtr, 1, BdPtr);
	if (Status != XST_SUCCESS) {
		/*
		 * Undo BD allocation and exit
		 */
		xil_printf("Length %d\r\n",
				XAxiDma_BdGetLength(BdPtr, TxRingPtr->MaxTransferLen));
		xil_printf("BD control bits %x\r\n", XAxiDma_BdGetCtrl(BdPtr));

		if (Status == XST_FAILURE)
			xil_printf("error 1\r\n");

		if (Status == XST_INVALID_PARAM)
			xil_printf("error 2\r\n");

		if (Status == XST_DMA_SG_LIST_ERROR)
			xil_printf("error 3\r\n");

		XAxiDma_BdRingUnAlloc(TxRingPtr, 1, BdPtr);
		xil_printf("Error committing TxBD to HW");
		return XST_FAILURE;
	}

	/*
	 * The least significant 4 bytes of the BD are used to hold
	 * the address of the "next" BD. Thus, by casting to a u32
	 * pointer, these bytes are altered. Set them to be equal
	 * the address of the own buffer, so that the BD ring is
	 * cyclic.
	 */
	u32 *ptr = (u32 *) BdPtr;
	*ptr = (u32) ptr;

	/*
	 * Set the tail to an address that is out of the BD region
	 * so that the hardware never finds it within the BDs
	 */
	TxRingPtr->HwTail = NULL;

	/*
	 * Start DMA TX channel. Transmission starts at once and
	 * continues forever.
	 */
	Status = XAxiDma_BdRingStart(TxRingPtr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}
