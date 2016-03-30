library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ad9361_data is
	generic(
		n_axc : integer := 2
	);
	port(
		-- Defaults
		adcClk : in std_logic;
		dacClk : in std_logic;
		axiClk : in std_logic;
		rst : in std_logic;

		-- AD9361 dac
		dac_i0_valid  : in std_logic;
		dac_i0_enable : in std_logic;
		dac_i0_data   : in std_logic_vector(15 downto 0);
		dac_q0_valid  : in std_logic;
		dac_q0_enable : in std_logic;
		dac_q0_data   : in std_logic_vector(15 downto 0);
		dac_i1_valid  : in std_logic;
		dac_i1_enable : in std_logic;
		dac_i1_data   : in std_logic_vector(15 downto 0);
		dac_q1_valid  : in std_logic;
		dac_q1_enable : in std_logic;
		dac_q1_data   : in std_logic_vector(15 downto 0);

		-- AD9361 adc
		dac_i0_valid  : in std_logic;
		dac_i0_enable : in std_logic;
		dac_i0_data   : in std_logic_vector(15 downto 0);
		dac_q0_valid  : in std_logic;
		dac_q0_enable : in std_logic;
		dac_q0_data   : in std_logic_vector(15 downto 0);
		dac_i1_valid  : in std_logic;
		dac_i1_enable : in std_logic;
		dac_i1_data   : in std_logic_vector(15 downto 0);
		dac_q1_valid  : in std_logic;
		dac_q1_enable : in std_logic;
		dac_q1_data   : in std_logic_vector(15 downto 0);

		-- DMA interface
		dac_dma_iq_tready : in std_logic;
		dac_dma_iq_tvalid : out std_logic;
		dac_dma_iq_tdata  : in std_logic_vector(64 downto 0)

		adc_dma_iq_tready : in std_logic;
		adc_dma_iq_tvalid : out std_logic;
		adc_dma_iq_tdata  : out std_logic_vector(64 downto 0)


	);
end ad9361_data;

architecture Behavioral of adcInterface is

	component dacInterface is
		port(
			dacClk : in std_logic;
			ethClk : in std_logic;
			rst : in std_logic;
			-- AXIS Input
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
		end component;

	component adcInterface
		port(
			-- Defaults
			adcClk : in std_logic;
			axiClk : in std_logic;
			rst : in std_logic;

			-- AD9361 input bus
			rx_i0_valid  : in std_logic;
			rx_i0_enable : in std_logic;
			rx_i0_data   : in std_logic_vector(15 downto 0);
			rx_q0_valid  : in std_logic;
			rx_q0_enable : in std_logic;
			rx_q0_data   : in std_logic_vector(15 downto 0);
			rx_i1_valid  : in std_logic;
			rx_i1_enable : in std_logic;
			rx_i1_data   : in std_logic_vector(15 downto 0);
			rx_q1_valid  : in std_logic;
			rx_q1_enable : in std_logic;
			rx_q1_data   : in std_logic_vector(15 downto 0);

			-- ADC Data out
			m_axis_iq_tready : in std_logic;
			m_axis_iq_tvalid : out std_logic;
			m_axis_iq_tdata  : out std_logic_vector(31 downto 0)
		);
	end component;

end Behavioral;
