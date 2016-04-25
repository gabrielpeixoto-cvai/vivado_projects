----------------------------------------------------------------------------------
-- Company: LaPS - UFPA
-- Engineer: Igor Freire
--
-- Create Date:    14:20:58 03/23/2015
-- Design Name:
-- Module Name:    dacInterface - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- 		Writes I and Q samples from an inbound AXIS interface into buffers that
-- are directly read by the DAC. The module has one AXIS interface for each AxC.
--
-- Note: it assumes "Q" comes in the MSB and "I" in the LSB.
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity dacInterface is
	port(
		dacClk : in std_logic;
		axiClk : in std_logic;
		rst : in std_logic;
		-- AXIS Input Commuter
		-- AxC 0
		s_axis_axc0_i_tready : out std_logic;
		s_axis_axc0_i_tvalid : in std_logic;
		s_axis_axc0_i_tdata  : in std_logic_vector(15 downto 0);
		s_axis_axc0_q_tready : out std_logic;
		s_axis_axc0_q_tvalid : in std_logic;
		s_axis_axc0_q_tdata  : in std_logic_vector(15 downto 0);
		-- AxC 1
		s_axis_axc1_i_tready : out std_logic;
		s_axis_axc1_i_tvalid : in std_logic;
		s_axis_axc1_i_tdata  : in std_logic_vector(15 downto 0);
		s_axis_axc1_q_tready : out std_logic;
		s_axis_axc1_q_tvalid : in std_logic;
		s_axis_axc1_q_tdata  : in std_logic_vector(15 downto 0);
		-- AD9361 output bus
		tx_i0_valid  : in  std_logic;
		tx_i0_enable : in  std_logic;
		tx_i0_data   : out std_logic_vector(15 downto 0);
		tx_q0_valid  : in  std_logic;
		tx_q0_enable : in  std_logic;
		tx_q0_data   : out std_logic_vector(15 downto 0);
		tx_i1_valid  : in  std_logic;
		tx_i1_enable : in  std_logic;
		tx_i1_data   : out std_logic_vector(15 downto 0);
		tx_q1_valid  : in  std_logic;
		tx_q1_enable : in  std_logic;
		tx_q1_data   : out std_logic_vector(15 downto 0);
		-- Interrupt signal to control DAC clock freq. and the
		-- control information to be read by the interrupt
		clkCtrlInterrupt : out std_logic;
		-- Status reports
		clkCtrlInterruptInfo: out std_logic_vector (31 downto 0)
	);
end dacInterface;

architecture Behavioral of dacInterface is

	COMPONENT native_fifo_8192x16
	PORT (
		rst : IN STD_LOGIC;
		wr_clk : IN STD_LOGIC;
		rd_clk : IN STD_LOGIC;
		wr_data_count : out std_logic_vector(12 downto 0);
		rd_data_count : out std_logic_vector(12 downto 0);
		din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		wr_en : IN STD_LOGIC;
		rd_en : IN STD_LOGIC;
		dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		full : OUT STD_LOGIC;
		empty : OUT STD_LOGIC
	);
	END COMPONENT;


	-- Fifo read enable signals
	signal i0_rd_en : std_logic;
	signal q0_rd_en : std_logic;
	signal i1_rd_en : std_logic;
	signal q1_rd_en : std_logic;

	-- Write enable signals for the FIFOs.
	signal axc0_i_fifo_wr_en : std_logic;
	signal axc0_q_fifo_wr_en : std_logic;
	signal axc1_i_fifo_wr_en : std_logic;
	signal axc1_q_fifo_wr_en : std_logic;

	-- Full signals
	signal i0_full : std_logic;
	signal q0_full : std_logic;
	signal i1_full : std_logic;
	signal q1_full : std_logic;

	-- FIFO Occupancy
	signal i0_fifo_occ : std_logic_vector(12 downto 0);

	-- Flags controlled by the "occupancy controller"
	signal iq_fifo_rd_enable : std_logic;
	--signal full_panic_flag : std_logic;

begin

	--------------------------------------------------------
	-- AxC 0
	--------------------------------------------------------

	-- Fifo of i0 Channel
	fifo_i0_i : native_fifo_8192x16
	PORT MAP (
		rst => rst,
		wr_clk => axiClk,
		rd_clk => dacClk,

		wr_data_count  => i0_fifo_occ,
		rd_data_count  => open,

		din => s_axis_axc0_i_tdata,
		wr_en => axc0_i_fifo_wr_en,

		rd_en => i0_rd_en,
		dout => tx_i0_data,

		full => i0_full,
		empty => open
	);

	-- Fifo of q0 Channel
	fifo_q0_i : native_fifo_8192x16
	PORT MAP (
		rst => rst,
		wr_clk => axiClk,
		rd_clk => dacClk,

		wr_data_count  => open,
		rd_data_count  => open,

		din => s_axis_axc0_q_tdata,
		wr_en => axc0_q_fifo_wr_en,

		rd_en => q0_rd_en,
		dout => tx_q0_data,

		full => q0_full,
		empty => open
	);

	--------------------------------------------------------
	-- AxC 1
	--------------------------------------------------------

	-- Fifo of i1 Channel
	fifo_i1_i : native_fifo_8192x16
	PORT MAP (
		rst => rst,
		wr_clk => axiClk,
		rd_clk => dacClk,

		wr_data_count  => open,
		rd_data_count  => open,

		din => s_axis_axc1_i_tdata,
		wr_en => axc1_i_fifo_wr_en,

		rd_en => i1_rd_en,
		dout => tx_i1_data,

		full => i1_full,
		empty => open
	);

	-- Fifo of q1 Channel
	fifo_q1_i : native_fifo_8192x16
	PORT MAP (
		rst => rst,
		wr_clk => axiClk,
		rd_clk => dacClk,

		wr_data_count  => open,
		rd_data_count  => open,

		din => s_axis_axc1_q_tdata,
		wr_en => axc1_q_fifo_wr_en,

		rd_en => q1_rd_en,
		dout => tx_q1_data,

		full => q1_full,
		empty => open
	);

	-------------------------------------------------------------------------
	-- Occupancy controller
	--
	-- Manages signals that control r/w into FIFOs.
	-------------------------------------------------------------------------

	-- Write enable signal for the IQ FIFOs above
	axc0_i_fifo_wr_en <= s_axis_axc0_i_tvalid; --and (not full_panic_flag);
	axc0_q_fifo_wr_en <= s_axis_axc0_q_tvalid; --and (not full_panic_flag);
	axc1_i_fifo_wr_en <= s_axis_axc1_i_tvalid; --and (not full_panic_flag);
	axc1_q_fifo_wr_en <= s_axis_axc1_q_tvalid; --and (not full_panic_flag);

	s_axis_axc0_i_tready <= tx_i0_valid and tx_i0_enable;
	s_axis_axc0_q_tready <= tx_q0_valid and tx_q0_enable;
	s_axis_axc1_i_tready <= tx_i1_valid and tx_i1_enable;
	s_axis_axc1_q_tready <= tx_q1_valid and tx_q1_enable;



	-- Read enable signal for the IQ FIFOs above.
	--i0_rd_en <= iq_fifo_rd_enable and tx_i0_valid and tx_i0_enable;
	--q0_rd_en <= iq_fifo_rd_enable and tx_q0_valid and tx_q0_enable;
	--i1_rd_en <= iq_fifo_rd_enable and tx_i1_valid and tx_i1_enable;
	--q1_rd_en <= iq_fifo_rd_enable and tx_q1_valid and tx_q1_enable;

	i0_rd_en <= tx_i0_valid and tx_i0_enable;
	q0_rd_en <= tx_q0_valid and tx_q0_enable;
	i1_rd_en <= tx_i1_valid and tx_i1_enable;
	q1_rd_en <= tx_q1_valid and tx_q1_enable;

end Behavioral;
