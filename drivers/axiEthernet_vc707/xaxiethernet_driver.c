/***************************** Include Files *********************************/

#include "xaxiethernet_driver.h"
#include "xllfifo.h"

#ifdef XPAR_XUARTNS550_NUM_INSTANCES
#include "xuartns550_l.h"
#endif

#if !defined (__MICROBLAZE__) && !defined(__PPC__)
#include "sleep.h"
#endif

/************************** Constant Definitions ****************************/

/*
 * The following constants map to the XPAR parameters created in the
 * xparameters.h file. They are defined here such that a user can easily
 * change all the needed parameters in one place.
 */
#ifndef TESTAPP_GEN
#define AXIETHERNET_DEVICE_ID	XPAR_AXIETHERNET_0_DEVICE_ID
#define FIFO_DEVICE_ID		XPAR_AXI_FIFO_0_DEVICE_ID
#endif

/************************** Variable Definitions ****************************/

XAxiEthernet AxiEthernetInstance;
XLlFifo FifoInstance;

/************************** Function Prototypes *****************************/

int initAxiEthernet(u16 AxiEthernetDeviceId, u16 FifoDeviceId);
int AxiEthernetResetDevice();

/*****************************************************************************/
/**
*
* This function demonstrates the usage of the Axi Ethernet by sending and
* receiving frames in polled mode.
*
*
* @param	AxiEthernetDeviceId is device ID of the AxiEthernet Device ,
*		typically XPAR_<AXIETHERNET_instance>_DEVICE_ID value from
*		xparameters.h
* @param	FifoDeviceId is device ID of the Fifo device taken from
*		xparameters.h
*
* @return	-XST_SUCCESS to indicate success
*		-XST_FAILURE to indicate failure
*
* @note		AxiFifo hardware must be initialized before initializing
*		AxiEthernet. Since AxiFifo reset line is connected to the
*		AxiEthernet reset line, a reset of AxiFifo hardware during its
*		initialization would reset AxiEthernet.
*
******************************************************************************/
int initAxiEthernet(u16 AxiEthernetDeviceId, u16 FifoDeviceId)
{
	int Status;
	XAxiEthernet_Config *MacCfgPtr;
	int Speed;

	/*************************************/
	/* Setup device for first-time usage */
	/*************************************/

	/*
	 *  Get the configuration of AxiEthernet hardware.
	 */
	MacCfgPtr = XAxiEthernet_LookupConfig(AxiEthernetDeviceId);

	/*
	 * Check whether AXIFIFO is present or not
	 */
	if(MacCfgPtr->AxiDevType != XPAR_AXI_FIFO) {
		AxiEthernetUtilErrorTrap
			("Device HW not configured for FIFO mode\r\n");
		return XST_FAILURE;
	}

	/*
	 * Initialize AXIFIFO hardware. AXIFIFO must be initialized before
	 * AxiEthernet. During AXIFIFO initialization, AXIFIFO hardware is
	 * reset, and since AXIFIFO reset line is connected to AxiEthernet,
	 * this would ensure a reset of AxiEthernet.
	 */
	XLlFifo_Initialize(&FifoInstance, MacCfgPtr->AxiDevBaseAddress);

	/*
	 * Initialize AxiEthernet hardware.
	 */
	Status = XAxiEthernet_CfgInitialize(&AxiEthernetInstance, MacCfgPtr,
					MacCfgPtr->BaseAddress);
	if (Status != XST_SUCCESS) {
		AxiEthernetUtilErrorTrap("Error in initialize");
		return XST_FAILURE;
	}

	/*
	 * Set the MAC  address
	 */
	Status = XAxiEthernet_SetMacAddress(&AxiEthernetInstance,
							(u8 *) AxiEthernetMAC);
	if (Status != XST_SUCCESS) {
		AxiEthernetUtilErrorTrap("Error setting MAC address");
		return XST_FAILURE;
	}


	/*
	 * Set PHY to loopback, speed depends on phy type.
	 * MII is 100 and all others are 1000.
	 */
	if (XAxiEthernet_GetPhysicalInterface(&AxiEthernetInstance) ==
							XAE_PHY_TYPE_MII) {
		Speed = AXIETHERNET_LOOPBACK_SPEED;
	} else {
		Speed = AXIETHERNET_LOOPBACK_SPEED_1G;
	}
	Status = AxiEthernetUtilEnterLoopback(&AxiEthernetInstance,
								Speed);
	if (Status != XST_SUCCESS) {
		AxiEthernetUtilErrorTrap("Error setting the PHY loopback");
		return XST_FAILURE;
	}


	/*
	 * Set PHY<-->MAC data clock
	 */
	Status =  XAxiEthernet_SetOperatingSpeed(&AxiEthernetInstance,
							(u16)Speed);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Setting the operating speed of the MAC needs a delay.  There
	 * doesn't seem to be register to poll, so please consider this
	 * during your application design.
	 */
	AxiEthernetUtilPhyDelay(2);

	/****************************/
	/* Run through the examples */
	/****************************/

	/*
	 * Run the Multiple Frames polled example
	 */
	XAxiEthernet_Start(&AxiEthernetInstance);

	return XST_SUCCESS;


}

/******************************************************************************/
/**
* This function resets the device but preserves the options set by the user.
*
* @param	None.
*
* @return	-XST_SUCCESS if reset is successful
*		-XST_FAILURE. if reset is not successful
*
* @note     None.
*
******************************************************************************/
int AxiEthernetResetDevice(void)
{
	int Status;
	u8 MacSave[6];
	u32 Options;

	/*
	 * Stop device
	 */
	XAxiEthernet_Stop(&AxiEthernetInstance);

	/*
	 * Save the device state
	 */
	XAxiEthernet_GetMacAddress(&AxiEthernetInstance, MacSave);
	Options = XAxiEthernet_GetOptions(&AxiEthernetInstance);

	/*
	 * Stop and reset both the fifo and the AxiEthernet the devices
	 */
	XLlFifo_Reset(&FifoInstance);
	XAxiEthernet_Reset(&AxiEthernetInstance);

	/*
	 * Restore the state
	 */
	Status = XAxiEthernet_SetMacAddress(&AxiEthernetInstance, MacSave);
	Status |= XAxiEthernet_SetOptions(&AxiEthernetInstance, Options);
	Status |= XAxiEthernet_ClearOptions(&AxiEthernetInstance, ~Options);
	if (Status != XST_SUCCESS) {
		AxiEthernetUtilErrorTrap("Error restoring state after reset");
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}


/******************************************************************************/
/**
*
* For Microblaze we use an assembly loop that is roughly the same regardless of
* optimization level, although caches and memory access time can make the delay
* vary.  Just keep in mind that after resetting or updating the PHY modes,
* the PHY typically needs time to recover.
*
* @return	None
*
* @note		None
*
******************************************************************************/
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

/******************************************************************************/
/**
*
* This function is called by example code when an error is detected. It
* can be set as a breakpoint with a debugger or it can be used to print out the
* given message if there is a UART or STDIO device.
*
* @param	Message is the text explaining the error
*
* @return	None
*
* @note		None
*
******************************************************************************/
void AxiEthernetUtilErrorTrap(char *Message)
{
	static int Count = 0;

	Count++;

#ifdef STDOUT_BASEADDRESS
	xil_printf("%s\r\n", Message);
#endif
}


/******************************************************************************/
/**
* Set PHY to loopback mode. This works with the marvell PHY common on ML40x
* evaluation boards
*
* @param Speed is the loopback speed 10, 100, or 1000 Mbit
*
******************************************************************************/
/* IEEE PHY Specific definitions */
#define PHY_R0_CTRL_REG		0
#define PHY_R3_PHY_IDENT_REG	3

#define PHY_R0_RESET         0x8000
#define PHY_R0_LOOPBACK      0x4000
#define PHY_R0_ANEG_ENABLE   0x1000
#define PHY_R0_DFT_SPD_MASK  0x2040
#define PHY_R0_DFT_SPD_10    0x0000
#define PHY_R0_DFT_SPD_100   0x2000
#define PHY_R0_DFT_SPD_1000  0x0040
#define PHY_R0_ISOLATE       0x0400

/* Marvel PHY 88E1111 Specific definitions */
#define PHY_R20_EXTND_CTRL_REG	20
#define PHY_R27_EXTND_STS_REG	27

#define PHY_R20_DFT_SPD_10    	0x20
#define PHY_R20_DFT_SPD_100   	0x50
#define PHY_R20_DFT_SPD_1000  	0x60
#define PHY_R20_RX_DLY		0x80

#define PHY_R27_MAC_CONFIG_GMII      0x000F
#define PHY_R27_MAC_CONFIG_MII       0x000F
#define PHY_R27_MAC_CONFIG_RGMII     0x000B
#define PHY_R27_MAC_CONFIG_SGMII     0x0004

/* Marvel PHY 88E1116R Specific definitions */
#define PHY_R22_PAGE_ADDR_REG	22
#define PHY_PG2_R21_CTRL_REG	21

#define PHY_REG21_10      0x0030
#define PHY_REG21_100     0x2030
#define PHY_REG21_1000    0x0070

/* Marvel PHY flags */
#define MARVEL_PHY_88E1111_MODEL	0xC0
#define MARVEL_PHY_88E1116R_MODEL	0x240
#define PHY_MODEL_NUM_MASK		0x3F0

/******************************************************************************/
/**
*
* This function sets the PHY to loopback mode. This works with the marvell PHY
* common on ML40x evaluation boards.
*
* @param	AxiEthernetInstancePtr is a pointer to the instance of the
*		AxiEthernet component.
* @param	Speed is the loopback speed 10, 100, or 1000 Mbit.
*
* @return	- XST_SUCCESS if successful.
*		- XST_FAILURE, in case of failure..
*
* @note		None.
*
******************************************************************************/
int AxiEthernetUtilEnterLoopback(XAxiEthernet *AxiEthernetInstancePtr,
								int Speed)
{
	u16 PhyReg0;
	signed int PhyAddr;
	u8 PhyType;
	u16 PhyModel;
	u16 PhyReg20;	/* Extended PHY specific Register (Reg 20)
			   of Marvell 88E1111 PHY */
	u16 PhyReg21;	/* Control Register MAC (Reg 21)
			   of Marvell 88E1116R PHY */

	/* Get the Phy Interface */
	PhyType = XAxiEthernet_GetPhysicalInterface(AxiEthernetInstancePtr);

	/* Detect the PHY address */
	// Note use AxiEthernetDetectPHY function from the example if not using 1000BASE_X
	PhyAddr = XPAR_AXIETHERNET_0_PHYADDR;


	XAxiEthernet_PhyRead(AxiEthernetInstancePtr, PhyAddr,
				PHY_R3_PHY_IDENT_REG, &PhyModel);
	PhyModel = PhyModel & PHY_MODEL_NUM_MASK;

	/* Clear the PHY of any existing bits by zeroing this out */
	PhyReg0 = PhyReg20 = PhyReg21 = 0;

	switch (Speed) {
	case XAE_SPEED_10_MBPS:
		PhyReg0 |= PHY_R0_DFT_SPD_10;
		PhyReg20 |= PHY_R20_DFT_SPD_10;
		PhyReg21 |= PHY_REG21_10;
		break;

	case XAE_SPEED_100_MBPS:
		PhyReg0 |= PHY_R0_DFT_SPD_100;
		PhyReg20 |= PHY_R20_DFT_SPD_100;
		PhyReg21 |= PHY_REG21_100;
		break;

	case XAE_SPEED_1000_MBPS:
		PhyReg0 |= PHY_R0_DFT_SPD_1000;
		PhyReg20 |= PHY_R20_DFT_SPD_1000;
		PhyReg21 |= PHY_REG21_1000;
		break;

	default:
		AxiEthernetUtilErrorTrap("Intg_LinkSpeed not 10, 100, or 1000 mbps");
		return XST_FAILURE;
	}

	/* RGMII mode Phy specific registers initialization */
	if ((PhyType == XAE_PHY_TYPE_RGMII_2_0) ||
		(PhyType == XAE_PHY_TYPE_RGMII_1_3)) {
		if (PhyModel == MARVEL_PHY_88E1111_MODEL) {
			PhyReg20 |= PHY_R20_RX_DLY;
			/*
			 * Adding Rx delay. Configuring loopback speed.
			 */
			XAxiEthernet_PhyWrite(AxiEthernetInstancePtr,
						PhyAddr, PHY_R20_EXTND_CTRL_REG,
						PhyReg20);
		} else if (PhyModel == MARVEL_PHY_88E1116R_MODEL) {
			/*
			 * Switching to PAGE2
			 */
			XAxiEthernet_PhyWrite(AxiEthernetInstancePtr,
						PhyAddr,
						PHY_R22_PAGE_ADDR_REG, 2);
			/*
			 * Adding Tx and Rx delay. Configuring loopback speed.
			 */
			XAxiEthernet_PhyWrite(AxiEthernetInstancePtr,
						PhyAddr,
						PHY_PG2_R21_CTRL_REG, PhyReg21);
			/*
			 * Switching to PAGE0
			 */
			XAxiEthernet_PhyWrite(AxiEthernetInstancePtr,
						PhyAddr,
						PHY_R22_PAGE_ADDR_REG, 0);
		}
		PhyReg0 &= (~PHY_R0_ANEG_ENABLE);
	}

	/* Configure interface modes */
	if (PhyModel == MARVEL_PHY_88E1111_MODEL) {
		if ((PhyType == XAE_PHY_TYPE_RGMII_2_0) ||
				(PhyType == XAE_PHY_TYPE_RGMII_1_3))  {
			XAxiEthernet_PhyWrite(AxiEthernetInstancePtr,
					PhyAddr, PHY_R27_EXTND_STS_REG,
					PHY_R27_MAC_CONFIG_RGMII);
		} else if (PhyType == XAE_PHY_TYPE_SGMII) {
			XAxiEthernet_PhyWrite(AxiEthernetInstancePtr,
					PhyAddr, PHY_R27_EXTND_STS_REG,
					PHY_R27_MAC_CONFIG_SGMII);
		} else if ((PhyType == XAE_PHY_TYPE_GMII) ||
				(PhyType == XAE_PHY_TYPE_MII)) {
			XAxiEthernet_PhyWrite(AxiEthernetInstancePtr,
					PhyAddr, PHY_R27_EXTND_STS_REG,
					PHY_R27_MAC_CONFIG_GMII );
		}
	}

	/* Set the speed and put the PHY in reset, then put the PHY in loopback */
	// TODO: change function name, since we are not setting in loopback
	AxiEthernetUtilPhyDelay(AXIETHERNET_PHY_DELAY_SEC);
	XAxiEthernet_PhyRead(AxiEthernetInstancePtr,PhyAddr,
				PHY_R0_CTRL_REG, &PhyReg0);


	if ((PhyType == XAE_PHY_TYPE_SGMII) ||
		(PhyType == XAE_PHY_TYPE_1000BASE_X)) {
		AxiEthernetUtilConfigureInternalPhy(AxiEthernetInstancePtr, Speed);
	}

	AxiEthernetUtilPhyDelay(1);

	return XST_SUCCESS;
}

/******************************************************************************/
/**
*
* This function configures the internal phy for SGMII and 1000baseX modes.
* *
* @param	AxiEthernetInstancePtr is a pointer to the instance of the
*		AxiEthernet component.
* @param	Speed is the loopback speed 10, 100, or 1000 Mbit.
*
* @return	- XST_SUCCESS if successful.
*		- XST_FAILURE, in case of failure..
*
* @note		None.
*
******************************************************************************/
int AxiEthernetUtilConfigureInternalPhy(XAxiEthernet *AxiEthernetInstancePtr,
					int Speed)
{
	u16 PhyReg0;
	signed int PhyAddr;

	PhyAddr = XPAR_AXIETHERNET_0_PHYADDR;

	/* Clear the PHY of any existing bits by zeroing this out */
	PhyReg0 = 0;
	XAxiEthernet_PhyRead(AxiEthernetInstancePtr, PhyAddr,
				 PHY_R0_CTRL_REG, &PhyReg0);

	PhyReg0 &= (~PHY_R0_ANEG_ENABLE);
	PhyReg0 &= (~PHY_R0_ISOLATE);

	switch (Speed) {
		case XAE_SPEED_10_MBPS:
			PhyReg0 |= PHY_R0_DFT_SPD_10;
			break;
		case XAE_SPEED_100_MBPS:
			PhyReg0 |= PHY_R0_DFT_SPD_100;
			break;
		case XAE_SPEED_1000_MBPS:
			PhyReg0 |= PHY_R0_DFT_SPD_1000;
			break;
		default:
			AxiEthernetUtilErrorTrap(
				"Intg_LinkSpeed not 10, 100, or 1000 mbps\n\r");
				return XST_FAILURE;
	}

	AxiEthernetUtilPhyDelay(1);
	XAxiEthernet_PhyWrite(AxiEthernetInstancePtr, PhyAddr,
				PHY_R0_CTRL_REG, PhyReg0);
	return XST_SUCCESS;
}
