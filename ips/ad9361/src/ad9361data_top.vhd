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
		dacClk : in std_logic;
		axiClk : in std_logic;
		rst : in std_logic;

		-- AD9361 dac
		dac_i0_valid  : in std_logic;
		dac_i0_enable : in std_logic;
		dac_i0_data   : out std_logic_vector(15 downto 0);
		dac_q0_valid  : in std_logic;
		dac_q0_enable : in std_logic;
		dac_q0_data   : out std_logic_vector(15 downto 0);
		dac_i1_valid  : in std_logic;
		dac_i1_enable : in std_logic;
		dac_i1_data   : out std_logic_vector(15 downto 0);
		dac_q1_valid  : in std_logic;
		dac_q1_enable : in std_logic;
		dac_q1_data   : out std_logic_vector(15 downto 0);

		-- AD9361 adc
		adc_i0_valid  : in std_logic;
		adc_i0_enable : in std_logic;
		adc_i0_data   : in std_logic_vector(15 downto 0);
		adc_q0_valid  : in std_logic;
		adc_q0_enable : in std_logic;
		adc_q0_data   : in std_logic_vector(15 downto 0);
		adc_i1_valid  : in std_logic;
		adc_i1_enable : in std_logic;
		adc_i1_data   : in std_logic_vector(15 downto 0);
		adc_q1_valid  : in std_logic;
		adc_q1_enable : in std_logic;
		adc_q1_data   : in std_logic_vector(15 downto 0);

		-- DMA interface
		dac_dma_iq_tready : out std_logic;
		dac_dma_iq_tvalid : in std_logic;
		dac_dma_iq_tdata  : in std_logic_vector(31 downto 0);

		adc_dma_iq_tready : in std_logic;
		adc_dma_iq_tvalid : out std_logic;
		adc_dma_iq_tdata  : out std_logic_vector(31 downto 0)


	);
end ad9361_data;

architecture Behavioral of ad9361_data is

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

	component dac_dmaInterface is
		port(
			-- Defaults
			clk_fs : in std_logic;
			clk_axi : in std_logic;
			rst : in std_logic;
			-- DMA AXIS Input
			s_axis_dma_tvalid : in std_logic;
			s_axis_dma_tready : out  std_logic;
			s_axis_dma_tdata  : in std_logic_vector(31 downto 0);
			-- Output of IQ samples through AXIS bus
			m_axis_i0_tready : in std_logic;
			m_axis_i0_tvalid : out std_logic;
			m_axis_i0_tdata  : out std_logic_vector(15 downto 0);

			m_axis_q0_tready : in std_logic;
			m_axis_q0_tvalid : out std_logic;
			m_axis_q0_tdata  : out std_logic_vector(15 downto 0);

			m_axis_i1_tready : in std_logic;
			m_axis_i1_tvalid : out std_logic;
			m_axis_i1_tdata  : out std_logic_vector(15 downto 0);

			m_axis_q1_tready : in std_logic;
			m_axis_q1_tvalid : out std_logic;
			m_axis_q1_tdata  : out std_logic_vector(15 downto 0)
		);

	end component;

	component adc_dmaInterface is
		generic(
			n_axc : integer := 2;
			compression_ratio  : integer := 1;
			dma_read_data_type : string  := "raw"
		);
		port(
			-- Defaults
			clk_fs : in std_logic;
			clk_axi : in std_logic;
			rst : in std_logic;
			-- DMA AXIS Input
			s_axis_adc_tvalid : in std_logic;
			s_axis_adc_tready : in  std_logic;
			s_axis_adc_tdata  : in std_logic_vector(31 downto 0);

			-- Input of IQ samples through AXIS bus
			m_axis_dma_tready : in std_logic;
			m_axis_dma_tvalid : out std_logic;
			m_axis_dma_tdata  : out std_logic_vector(31 downto 0)
		);
	end component;

	--signals
	--dac signals
	signal tx_i0_valid  : std_logic;
	signal tx_i0_enable : std_logic;
	signal tx_i0_data   : std_logic_vector(15 downto 0);
	signal tx_q0_valid  : std_logic;
	signal tx_q0_enable : std_logic;
	signal tx_q0_data   : std_logic_vector(15 downto 0);
	signal tx_i1_valid  : std_logic;
	signal tx_i1_enable : std_logic;
	signal tx_i1_data   : std_logic_vector(15 downto 0);
	signal tx_q1_valid  : std_logic;
	signal tx_q1_enable : std_logic;
	signal tx_q1_data   : std_logic_vector(15 downto 0);

	--adc signalsac_dma_iq_tvalid;
	signal adc_rx_i0_valid	:	std_logic;
	signal adc_rx_i0_enable	:	std_logic;
	signal adc_rx_i0_data   : std_logic_vector(15 downto 0);
	signal adc_rx_q0_valid  : std_logic;
	signal adc_rx_q0_enable : std_logic;
	signal adc_rx_q0_data   : std_logic_vector(15 downto 0);
	signal adc_rx_i1_valid  : std_logic;
	signal adc_rx_i1_enable : std_logic;
	signal adc_rx_i1_data   : std_logic_vector(15 downto 0);
	signal adc_rx_q1_valid  : std_logic;
	signal adc_rx_q1_enable : std_logic;
	signal adc_rx_q1_data   : std_logic_vector(15 downto 0);

	signal dma_tx_i0_valid  : std_logic;
	signal dma_tx_i0_enable : std_logic;
	signal dma_tx_i0_data   : std_logic_vector(15 downto 0);
	signal dma_tx_q0_valid  : std_logic;
	signal dma_tx_q0_enable : std_logic;
	signal dma_tx_q0_data   : std_logic_vector(15 downto 0);
	signal dma_tx_i1_valid  : std_logic;
	signal dma_tx_i1_enable : std_logic;
	signal dma_tx_i1_data   : std_logic_vector(15 downto 0);
	signal dma_tx_q1_valid  : std_logic;
	signal dma_tx_q1_enable : std_logic;
	signal dma_tx_q1_data   : std_logic_vector(15 downto 0);

	signal dma_rx_iq_valid  : std_logic;
	signal dma_rx_iq_enable : std_logic;
	signal dma_rx_iq_data   : std_logic_vector(31 downto 0);

	--dma signals
	-- DMA interface
	signal sig_dac_dma_iq_tready : std_logic;
	signal sig_dac_dma_iq_tvalid : std_logic;
	signal sig_dac_dma_iq_tdata  : std_logic_vector(31 downto 0);

	signal sig_adc_dma_iq_tready : std_logic;
	signal sig_adc_dma_iq_tvalid : std_logic;
	signal sig_adc_dma_iq_tdata  : std_logic_vector(31 downto 0);

	-- Clock frequency at the sampling frequency
	signal bufr_out : std_logic;
	signal clk_fs : std_logic;

begin

--------------------------------------------------------------------------------
-- `lclk` is by default at 4 * sampling frequency. However, both the
-- cpriEmulator and the dmaInterface require the exact sampling frequency. The
-- following modules generate such a clock.
--------------------------------------------------------------------------------

	BUFR_inst : BUFR
	generic map (
		BUFR_DIVIDE => "4",      -- Values: "BYPASS, 1, 2, 3, 4, 5, 6, 7, 8"
		SIM_DEVICE => "7SERIES"  -- Must be set to "7SERIES"
	)
	port map (
		O => bufr_out,  -- Clock output port
		CE => '1',    -- Active high, clock enable (Divided modes only)
		CLR => '0',   -- Active high, asynchronous clear (Divided modes only)
		I => adcClk  -- Clock buffer input
	);

	BUFG_inst : BUFG
	port map (
		O => clk_fs, -- 1-bit output: Clock output
		I => bufr_out  -- 1-bit input: Clock input
	);

--------------------------------------------------------------------------------

	dma_dac : dac_dmaInterface
		port map(
			-- Defaults
			clk_fs => clk_fs,
			clk_axi => axiClk,
			rst => rst,
			-- DMA AXIS Input
			s_axis_dma_tvalid => dac_dma_iq_tvalid,
			s_axis_dma_tready => dac_dma_iq_tready,
			s_axis_dma_tdata  => dac_dma_iq_tdata,

			-- Output of IQ samples through AXIS bus
			m_axis_i0_tready => dma_tx_i0_valid,
			m_axis_i0_tvalid => dma_tx_i0_valid,
			m_axis_i0_tdata  => dma_tx_i0_data,

			m_axis_q0_tready => dma_tx_q0_enable,
			m_axis_q0_tvalid => dma_tx_q0_valid,
			m_axis_q0_tdata  => dma_tx_q0_data,

			m_axis_i1_tready => dma_tx_i1_enable,
			m_axis_i1_tvalid => dma_tx_i1_valid,
			m_axis_i1_tdata  => dma_tx_i1_data,

			m_axis_q1_tready => dma_tx_q1_enable,
			m_axis_q1_tvalid => dma_tx_q1_valid,
			m_axis_q1_tdata  => dma_tx_q1_data
		);

	dac_if : dacInterface
		port map(
			dacClk => adcClk,
			ethClk => axiClk,
			rst => rst,
			-- AXIS Input
			-- AxC 0
			s_axis_axc0_i_tready => dma_tx_i0_enable,
			s_axis_axc0_i_tvalid => dma_tx_i0_valid,
			s_axis_axc0_i_tdata  => dma_tx_i0_data,
			s_axis_axc0_q_tready => dma_tx_q0_enable,
			s_axis_axc0_q_tvalid => dma_tx_q0_valid,
			s_axis_axc0_q_tdata  => dma_tx_q0_data,
			-- AxC 1
			s_axis_axc1_i_tready => dma_tx_i1_enable,
			s_axis_axc1_i_tvalid => dma_tx_i1_valid,
			s_axis_axc1_i_tdata  => dma_tx_i1_data,
			s_axis_axc1_q_tready => dma_tx_q1_enable,
			s_axis_axc1_q_tvalid => dma_tx_q1_valid,
			s_axis_axc1_q_tdata  => dma_tx_q1_data,
			-- AD9361 output bus
			tx_i0_valid  => dac_i0_valid,
			tx_i0_enable => dac_i0_enable,
			tx_i0_data   => dac_i0_data,
			tx_q0_valid  => dac_q0_valid,
			tx_q0_enable => dac_q0_enable,
			tx_q0_data   => dac_q0_data,
			tx_i1_valid  => dac_i1_valid,
			tx_i1_enable => dac_i1_enable,
			tx_i1_data   => dac_i1_data,
			tx_q1_valid  => dac_q1_valid,
			tx_q1_enable => dac_q1_enable,
			tx_q1_data   => dac_q1_data,
			-- Interrupt signal to control DAC clock freq. and the
			-- control information to be read by the interrupt
			clkCtrlInterrupt 			=>	open,
			-- Status reports
			clkCtrlInterruptInfo 	=>	open

		);

		dma_adc : adc_dmaInterface
			port map(
				-- Defaults
				clk_fs => dacClk,
				clk_axi => axiClk,
				rst => rst,
				-- ADC Input
				s_axis_adc_tvalid => sig_adc_dma_iq_tvalid,
				s_axis_adc_tready => sig_adc_dma_iq_tready,
				s_axis_adc_tdata  => sig_adc_dma_iq_tdata,

				-- Output DMA
				m_axis_dma_tready => adc_dma_iq_tready,
				m_axis_dma_tvalid => adc_dma_iq_tvalid,
				m_axis_dma_tdata  => adc_dma_iq_tdata
			);

		adc_if : adcInterface
			port map(
				adcClk => adcClk,
				axiClk => axiClk,
				rst => rst,

				-- AD9361 input bus
				rx_i0_valid  => adc_i0_valid,
				rx_i0_enable => adc_i0_enable,
				rx_i0_data   => adc_i0_data,
				rx_q0_valid  => adc_q0_valid,
				rx_q0_enable => adc_q0_enable,
				rx_q0_data   => adc_q0_data,
				rx_i1_valid  => adc_i1_valid,
				rx_i1_enable => adc_i1_enable,
				rx_i1_data   => adc_i1_data,
				rx_q1_valid  => adc_q1_valid,
				rx_q1_enable => adc_q1_enable,
				rx_q1_data   => adc_q1_data,

				-- Outuput of IQ samples through AXIS bus
				m_axis_iq_tready => sig_adc_dma_iq_tready,
				m_axis_iq_tvalid => sig_adc_dma_iq_tvalid,
				m_axis_iq_tdata  => sig_adc_dma_iq_tdata

			);


end Behavioral;
