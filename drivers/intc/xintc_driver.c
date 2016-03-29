/**
 *
 * Registers:
 * 	Interrupt Status Register (ISR) 		-- R/W
 * 		Indicates active interrupts. It can be written to simulate interrupts
 * 		through software if the HIE bit in the MER is not active.
 *
 *	Interrupt Enable Register (IER) 		-- R/W
 *		Enables/disables interrupts. An IER bit set to 0 does not inhibit an
 * 		interrupt condition for being captured, but only prevents the interrupt
 * 		from being passed to the processor. It can be used to mask interrupts.
 *
 * 	Interrupt Pending Register (IPR)		-- Read-only
 *		Indicates active interrupts that are enabled. It is the logical AND
 * 		of the bits in the ISR and the IER.
 *
 *	Interrupt Acknowledge Register (IAR)	-- Write-only
 *		Clears the interrupt request associated with selected interrupt.
 *
 * 	Master Enable Register (MER)			-- R/W
 *		2 bits (LSB) : Master Enable and Hardware Interrupt Enable
 *
 * 	Interrupt Mode Register (IMR)			-- R/W
 *		Used to select fast interrupt mode.
 *
 *  Interrupt Level Register (ILR)			-- R/W
 * 		Allows blocking of interrupts with lower priority. Its value is
 * 		identical to the highest priority interrupt not allowed to generate IRQ.
 *
 */

/***************************** Include Files *********************************/

#include "xparameters.h"
#include "xstatus.h"
#include "xintc.h"
#include "xil_exception.h"

/************************** Constant Definitions *****************************/
// Interrupt controller
#define INTC_DEVICE_ID		  XPAR_INTC_0_DEVICE_ID

#define ROE_INTR_ID	  		  XPAR_MICROBLAZE_0_AXI_INTC_RADIO_OVER_ETHERNET_0_INTERRUPT_INTR

#define ACK_WAIT_TIMEOUT 	  1000

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

int XIntc_AckAll(XIntc * InstancePtr);

/************************** Variable Definitions *****************************/

static XIntc InterruptController; /* Instance of the Interrupt Controller */

/*****************************************************************************/
/**
 *
 * This function is an example of how to use the interrupt controller driver
 * component (XIntc) and the hardware device.  This function is designed to
 * work without any hardware devices to cause interrupts.  It may not return
 * if the interrupt controller is not properly connected to the processor in
 * either software or hardware.
 *
 * This function relies on the fact that the interrupt controller hardware
 * has come out of the reset state such that it will allow interrupts to be
 * simulated by the software.
 *
 * @param	DeviceId is Device ID of the Interrupt Controller Device,
 *		typically XPAR_<INTC_instance>_DEVICE_ID value from
 *		xparameters.h.
 *
 * @return	XST_SUCCESS to indicate success, otherwise XST_FAILURE.
 *
 * @note		None.
 *
 ******************************************************************************/
int initIntc() {
	int Status;
	u32 MasterEnable;
	u32 Temp;

	/*
	 * Initialize the interrupt controller driver so that it is ready to
	 * use.
	 */
	if (InterruptController.IsReady != 0) {
		xil_printf("Interrupt controller is not ready");
		return XST_FAILURE;
	}

	Status = XIntc_Initialize(&InterruptController, INTC_DEVICE_ID);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Check Hardware Interrupt Enable (HIE) bit in the MER before self test, because
	 * the software interrupt test would otherwise fail, since HIE bit is a write-once bit
	 * (a 1 written to it can not be deasserted except through reset of the device).
	 */
	MasterEnable = XIntc_In32(InterruptController.BaseAddress + XIN_MER_OFFSET);
	if (MasterEnable & XIN_INT_HARDWARE_ENABLE_MASK) {
		/*
		 * Assure all interrupts are cleared
		 */
		xil_printf("\r\n------------");
		xil_printf(
				"\r\nWarning: Hardware Interrupts already enabled in the Interrupt Controller.");
		xil_printf("\r\nConsider acknowledging all pending interrupts.");
		xil_printf("\r\nUse the \"XIntc_AckAll()\" function.");
		xil_printf("\r\n------------\r\n");
	} else {
		/*
		 * Perform a self-test to ensure that the hardware was built correctly.
		 */
		Status = XIntc_SelfTest(&InterruptController);
		if (Status != XST_SUCCESS) {
			return XST_FAILURE;
		}
	}

	/*
	 * Reset the Interrupt Level Register to its default value
	 */
	XIntc_Out32(InterruptController.BaseAddress + XIN_ILR_OFFSET, 0xFFFFFFFF);
	Temp = XIntc_In32(InterruptController.BaseAddress + XIN_ILR_OFFSET);
	xil_printf("ILR Config \t %x \r\n", Temp);

	/*
	 * Start the interrupt controller such that interrupts are enabled for
	 * all devices that cause interrupts
	 */
	Status = XIntc_Start(&InterruptController, XIN_REAL_MODE);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Initialize the exception table.
	 */
	Xil_ExceptionInit();

	/*
	 * Register the interrupt controller handler with the exception table.
	 */
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
			(Xil_ExceptionHandler) XIntc_InterruptHandler,
			&InterruptController);

	/*
	 * Enable exceptions.
	 */
	Xil_ExceptionEnable();

	Temp = XIntc_In32(InterruptController.BaseAddress + XIN_IMR_OFFSET);
	xil_printf("Interrupt Mode \t %x \r\n", Temp);

	return XST_SUCCESS;

}

/******************************************************************************/
/**
 *
 * This function connects the interrupt handler of the interrupt controller to
 * the processor.  This function is seperate to allow it to be customized for
 * each application.  Each processor or RTOS may require unique processing to
 * connect the interrupt handler.
 *
 * @param	None.
 *
 * @return	None.
 *
 * @note		None.
 *
 ****************************************************************************/
int SetUpInterruptSystem(u8 InterruptId, XInterruptHandler Handler,
		void *CallBackRef) {
	int Status;
	u32 Temp;
	Temp = XIntc_In32(InterruptController.BaseAddress + XIN_ISR_OFFSET);
	xil_printf("ISR \t %x", Temp);
	XIntc_Out32(InterruptController.BaseAddress + XIN_IAR_OFFSET, Temp);

	/*
	 * Connect a device driver handler that will be called when an interrupt
	 * for the device occurs, the device driver handler performs the
	 * specific interrupt processing for the device.
	 */
	Status = XIntc_Connect(&InterruptController, InterruptId, Handler,
			CallBackRef);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}
	/*
	 * TODO - check whether fast interrupt mode has been enabled at the Interrupt Mode
	 * Register (IMR)
	 */

	/*
	 * Enable the interrupt for the device and then cause (simulate) an
	 * interrupt so the handlers will be called.
	 */
	XIntc_Enable(&InterruptController, InterruptId);

	return XST_SUCCESS;

}

int ConnectInterrupt(u8 InterruptId, XInterruptHandler Handler,
		void *CallBackRef) {
	int Status;

	/*
	 * Connect a device driver handler that will be called when an interrupt
	 * for the device occurs, the device driver handler performs the
	 * specific interrupt processing for the device.
	 */
	xil_printf("Connecting Interrupt Id: %d", InterruptId);
	Status = XIntc_Connect(&InterruptController, InterruptId, Handler,
			CallBackRef);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	return XST_SUCCESS;

}

int XIntc_AckAll(XIntc * InstancePtr) {
	u32 CurrentISR = 1; // Non-zero value to enter while loop
	u32 Temp;
	u32 Timeout = ACK_WAIT_TIMEOUT;

	/*
	 * Assert the arguments
	 */
	Xil_AssertNonvoid(InstancePtr != NULL);
	Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

	while (CurrentISR != 0) {
		/*
		 * Acknowledge all pending interrupts by reading the interrupt status
		 * register and writing the value to the acknowledge register
		 */
		Temp = XIntc_In32(InstancePtr->BaseAddress + XIN_ISR_OFFSET);

		XIntc_Out32(InstancePtr->BaseAddress + XIN_IAR_OFFSET, Temp);

		/*
		 * Verify that there are no interrupts by reading the interrupt status
		 */
		CurrentISR = XIntc_In32(InstancePtr->BaseAddress + XIN_ISR_OFFSET);

		/*
		 * ISR should be zero after all interrupts are acknowledged
		 */
		if (Timeout-- == 0) {
			xil_printf("Could not ACK all interrupts\r\n");
			xil_printf("Interrupt Status Register (ISR): \t %d \r\n",
					CurrentISR);
			return XST_INTC_FAIL_SELFTEST;
		}
	}

	return XST_SUCCESS;
}

/****************************
 * Wrappers
 */

/**
 * Acknowledge interrupt
 */
void ackInterrupt(u8 InterruptId) {
	XIntc_Acknowledge(&InterruptController, InterruptId);
}

/**
 * Disable interrupt
 */
void disableInterrupt(u8 InterruptId) {
	XIntc_Disable(&InterruptController, InterruptId);
}

/**
 * Disable interrupt
 */
void enableInterrupt(u8 InterruptId) {
	XIntc_Enable(&InterruptController, InterruptId);
}

/**
 * Prevent interrupts up to a given priority
 *
 * InterruptId -> highest priority prevented from
 * generating a processor IRQ
 */
void preventIrqUpTo(u8 InterruptId) {
	XIntc_Out32(InterruptController.BaseAddress + XIN_ILR_OFFSET, InterruptId);
}

/**
 * Allow all IRQs in the ILR
 */
void allowAllIrq() {
	XIntc_Out32(InterruptController.BaseAddress + XIN_ILR_OFFSET, 0xFFFFFFFF);
}

