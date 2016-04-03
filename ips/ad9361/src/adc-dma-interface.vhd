--------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    14:20:58 03/23/2015
-- Design Name:
-- Module Name:    DMA Interface - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- DMA Interface - Receives IQ samples from the DMA and constrains the rate in
-- which IQ data enters the RoE subsystem. Transmits the IQ samples downstream
-- for CPRI encapsulation.
--
-- The approach adopted to constrain the data rate is to add two AXIS FIFO
-- stages. The first converts from the "AXIS clock" at the DMA input to the
-- "CPRI clock". The second converts back to AXIS clock that is used in the CPRI
-- packer that follows. The effect is that this creates a bottleneck and
-- controls the flow of data emulating the CPRI rate.
--
-- Important notes:
--
-- First and foremost, this module has to be driven by a clock whose frequency
-- is equal to the sampling frequency.
--
-- The number of bits transported within the critical path between FIFO 1 and
-- FIFO 2 (clocked with the sampling frquency) is determined by the number of
-- AxC in the system, the CPRI line rate option and the oversampling ratio with
-- respect to the chip rate (3.84 MHz). The first two parameters are
-- configurable by generics, but the latter has to be picked correctly by the
-- user of the RoE subsystem. For example, for fs = 7.68 MHz, line rate option
-- #1 and 2 AxC in the system, since the oversampling ratio is 2 (7.68 = 2 *
-- 3.84) the BF has to be formed within 2 sampling periods, so the first stage
-- FIFO has to release enough IQ samples for one BF within 2 clock cycles
-- (sampling periods). Then, since the BFs are 128 bit wide for option #1, 64
-- bits must me produced in each clock cycle, and since there are 2 AxC, each
-- clock cycle brings 2 32-bit IQ samples, one for each AxC. Another situation
-- for option #1 is a sampling frequency of 15.36 MHz, namely an oversampling
-- ratio of 4. In this case, only 1 AxC can be supported for option #1 and the
-- BF is formed within 4 clock cycles. Thus, the first stage FIFO should release
-- 32 bits in each clock cycle (a total of 128 in 4 cycles). For completeness,
-- let's look at a third example for line rate option #2 and clock of 7.68 MHz.
-- In this case, the oversampling is 2 again, but 4 AxC are supported and the
-- BFs are 256 bit wide. Hence, the BF has to be formed within 2 sampling
-- periods, so that the first stage FIFO should release 128 bits in each clock
-- cycle. Clearly, the number of bits released by the first stage FIFO to the
-- second stage FIFO depends on the number of AxC in the system. The user only
-- needs to guarantee that the actual line rate option supports this number of
-- AxC and that the clock fed into the RoE subsystem is appropriate.
--
-- The approach to satisfy the number of bits in the path between the first and
-- second stage FIFOs is to use a demux in this module's entrance and a mux in
-- the output. Then, "n_axc" paths of first and second stage FIFOs are used.
-- Each path takes one turn assigned by the demux (working as a commutator) and,
-- as a result, the output is ready in the end of each path in alternated clock
-- cycles. In the end, the multiplexer serializes back the transmission in the
-- desired rate for BF transmissions.
--
-- A final note is with respect to compression prior to DMA read. When
-- compressed IQ samples are read by the DMA instead of raw IQ samples, the
-- situation changes. Consider for example 2 LTE 20 MHz AxC compressed by a
-- ratio of 4. This LTE bandwidth requires a sampling frequency of 30.72, namely
-- an oversampling ratio of 8. Hence, this (30.72) is the clock that would be
-- fed to the DMA interface. By considering only the sampling freq. based on the
-- previous analysis, it would be concluded that the BF should be formed in 8
-- clock cycles. Moreover, in 8 clock cycles @ 30.72 with 2 AxC (and therefore
-- two concurrent and commuted paths of FIFOs), 512 bits would be acquired, so
-- it would be concluded that CPRI line rate option #3 (4 bytes per CPRI word)
-- would be required.
--
-- None of these conclusions are appropriate due to the compression ratio of 4
-- in the data being read via DMA. With this ratio, the CPRI words should be 4
-- times smaller than without compression, namely they should be 1-byte wide, so
-- that line rate option #1 is appropriate. Furthermore, the critical path
-- between the interface and internal FIFOs can not be clocked by a 30.72 MHz
-- clock without further modifications in the design. If this was done, in the
-- interval corresponding to 1 chip period, 4 times more data would be read than
-- necessary. In this context, to control the inflow of data, when
-- `dma_read_data_type = "compressed"` the clock used by the DMA interface
-- components (signal `used_clk`) is divided by the compression ratio. Then, the
-- critical path is clocked with 7.68 MHz, so that in 1 chip period, only 128
-- bits are acquired in accordance to the requirement for line rate option #1.

--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real."log2";

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity adc_dmaInterface is
	generic(
		n_axc : integer := 2;
		compression_ratio  : integer := 2;
		dma_read_data_type : string  := "raw"
	);
	port(
		-- Defaults
		clk_fs : in std_logic;
		clk_axi : in std_logic;
		rst : in std_logic;
		-- input from adc
		s_axis_adc_tvalid : in std_logic;
		s_axis_adc_tready : in  std_logic;
		s_axis_adc_tdata  : in std_logic_vector(31 downto 0);

		-- Outuput to dma
		m_axis_dma_tready : in std_logic;
		m_axis_dma_tvalid : out std_logic;
		m_axis_dma_tdata  : out std_logic_vector(31 downto 0)
	);
end adc_dmaInterface;

architecture Behavioral of adc_dmaInterface is

	component axis_mux is
	generic(
		DATA_WIDTH : integer := 32
	);
	port (
		clk : in std_logic;
		aresetn : in std_logic;
		-- Selector
		selector: in std_logic_vector(1 downto 0);
		-- Receive Stream 0
		s_axis_rx0_tready   : out std_logic;
		s_axis_rx0_tdata    : in  std_logic_vector (DATA_WIDTH-1 downto 0);
		s_axis_rx0_tvalid   : in  std_logic;
		-- Receive Stream 1
		s_axis_rx1_tready   : out std_logic;
		s_axis_rx1_tdata    : in  std_logic_vector (DATA_WIDTH-1 downto 0);
		s_axis_rx1_tvalid   : in  std_logic;
		-- Receive Stream 2
		s_axis_rx2_tready   : out std_logic;
		s_axis_rx2_tdata    : in  std_logic_vector (DATA_WIDTH-1 downto 0);
		s_axis_rx2_tvalid   : in  std_logic;
		-- Receive Stream 3
		s_axis_rx3_tready   : out std_logic;
		s_axis_rx3_tdata    : in  std_logic_vector (DATA_WIDTH-1 downto 0);
		s_axis_rx3_tvalid   : in  std_logic;
		-- Transmit Stream
		m_axis_tready  : in  std_logic;
		m_axis_tdata   : out  std_logic_vector (DATA_WIDTH-1 downto 0);
		m_axis_tvalid  : out  std_logic
	);
	end component;

	component stream_demux is
	generic(
		DATA_WIDTH : integer := 32;
		USER_WIDTH : integer := 96
	);
	port (
		-- Selector
		demux_selector: in STD_LOGIC_VECTOR(1 downto 0);
		-- Receive Stream: Axi Stream Slave
		RXD_S_AXIS_ACLK : in  STD_LOGIC;
		RXD_S_AXIS_ARESETN : in  STD_LOGIC;
		RXD_S_AXIS_TREADY : out  STD_LOGIC;
		RXD_S_AXIS_TDATA : in  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
		RXD_S_AXIS_TLAST : in  STD_LOGIC;
		RXD_S_AXIS_TVALID : in  STD_LOGIC;
		RXD_S_AXIS_TUSER : in  STD_LOGIC_VECTOR (USER_WIDTH-1 downto 0);
		RXD_S_AXIS_TKEEP : in  STD_LOGIC_VECTOR ((DATA_WIDTH/8)-1 downto 0);
		-- Transmit Stream: Axi Stream Master 0
		RXD_M0_AXIS_TREADY : in  STD_LOGIC;
		RXD_M0_AXIS_TDATA : out  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
		RXD_M0_AXIS_TLAST : out  STD_LOGIC;
		RXD_M0_AXIS_TVALID : out  STD_LOGIC;
		RXD_M0_AXIS_TUSER : out  STD_LOGIC_VECTOR (USER_WIDTH-1 downto 0);
		RXD_M0_AXIS_TKEEP : out  STD_LOGIC_VECTOR ((DATA_WIDTH/8)-1 downto 0);
		-- Transmit Stream: Axi Stream Master 1
		RXD_M1_AXIS_TREADY : in  STD_LOGIC;
		RXD_M1_AXIS_TDATA : out  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
		RXD_M1_AXIS_TLAST : out  STD_LOGIC;
		RXD_M1_AXIS_TVALID : out  STD_LOGIC;
		RXD_M1_AXIS_TUSER : out  STD_LOGIC_VECTOR (USER_WIDTH-1 downto 0);
		RXD_M1_AXIS_TKEEP : out  STD_LOGIC_VECTOR ((DATA_WIDTH/8)-1 downto 0);
		-- Transmit Stream: Axi Stream Master 2
		RXD_M2_AXIS_TREADY : in  STD_LOGIC;
		RXD_M2_AXIS_TDATA : out  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
		RXD_M2_AXIS_TLAST : out  STD_LOGIC;
		RXD_M2_AXIS_TVALID : out  STD_LOGIC;
		RXD_M2_AXIS_TUSER : out  STD_LOGIC_VECTOR (USER_WIDTH-1 downto 0);
		RXD_M2_AXIS_TKEEP : out  STD_LOGIC_VECTOR ((DATA_WIDTH/8)-1 downto 0);
		-- Transmit Stream: Axi Stream Master 3
		RXD_M3_AXIS_TREADY : in  STD_LOGIC;
		RXD_M3_AXIS_TDATA : out  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
		RXD_M3_AXIS_TLAST : out  STD_LOGIC;
		RXD_M3_AXIS_TVALID : out  STD_LOGIC;
		RXD_M3_AXIS_TUSER : out  STD_LOGIC_VECTOR (USER_WIDTH-1 downto 0);
		RXD_M3_AXIS_TKEEP : out  STD_LOGIC_VECTOR ((DATA_WIDTH/8)-1 downto 0)
		);
	end component;

	-- Master 32-bit wide and Slave 32-bit wide, Depth of 64
	COMPONENT fifo_axis_m_d64_w32_s_w32
	PORT (
		m_aclk : IN STD_LOGIC;
		s_aclk : IN STD_LOGIC;
		s_aresetn : IN STD_LOGIC;
		s_axis_tvalid : IN STD_LOGIC;
		s_axis_tready : OUT STD_LOGIC;
		s_axis_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		m_axis_tvalid : OUT STD_LOGIC;
		m_axis_tready : IN STD_LOGIC;
		m_axis_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		axis_overflow : OUT STD_LOGIC;
		axis_underflow : OUT STD_LOGIC
	);
	END COMPONENT;

	-- Constants
	constant nReadyCntBits : integer := integer(log2(real(compression_ratio)));

	--
	-- Signals
	--
	signal axis_aresetn : std_logic;

	-- For Receive and Transmit transactions:
	signal adc_rx_transaction : std_logic;
	signal downstream_tx_transaction : std_logic;
	signal sig_s_axis_adc_tready : std_logic;
	signal sig_m_axis_dma_tvalid : std_logic;

	-- Select signals for the Mux and the Demux
	signal mux_select : unsigned(1 downto 0);
	signal demux_select : unsigned(1 downto 0);

	-- From the demux to the interface FIFO
	signal sig_demux_AxC0_tvalid, sig_demux_AxC0_tready : std_logic;
	signal sig_demux_AxC0_tdata : std_logic_vector(31 downto 0);
	signal sig_demux_AxC1_tvalid, sig_demux_AxC1_tready : std_logic;
	signal sig_demux_AxC1_tdata : std_logic_vector(31 downto 0);

	-- From the interface FIFO to the internal FIFO
	signal sig_fifo_stage1_AxC0_tvalid, sig_fifo_stage1_AxC0_tready : std_logic;
	signal sig_fifo_stage1_AxC0_tdata : std_logic_vector(31 downto 0);
	signal sig_fifo_stage1_AxC1_tvalid, sig_fifo_stage1_AxC1_tready : std_logic;
	signal sig_fifo_stage1_AxC1_tdata : std_logic_vector(31 downto 0);

	-- From the internal FIFO to the CPRI packer
	signal sig_fifo_stage2_AxC0_tvalid, sig_fifo_stage2_AxC0_tready : std_logic;
	signal sig_fifo_stage2_AxC0_tdata : std_logic_vector(31 downto 0);
	signal sig_fifo_stage2_AxC1_tvalid, sig_fifo_stage2_AxC1_tready : std_logic;
	signal sig_fifo_stage2_AxC1_tdata : std_logic_vector(31 downto 0);

	signal used_clk : std_logic;
begin

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	Configure the internal clocking
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

bufr_clk_divider: if dma_read_data_type = "compressed" generate
	BUFR_inst : BUFR
	generic map (
	 BUFR_DIVIDE => integer'image(compression_ratio), -- Values: "BYPASS, 1, 2, 3, 4, 5, 6, 7, 8"
	 SIM_DEVICE => "7SERIES"           -- Must be set to "7SERIES"
	)
	port map (
	 O => used_clk, -- Clock output port
	 CE => '1',     -- Active high, clock enable (Divided modes only)
	 CLR => '0',    -- Active high, asynchronous clear (Divided modes only)
	 I => clk_fs    -- Clock buffer input
	);
end generate;

clk_bypass: if dma_read_data_type /= "compressed" generate
	used_clk <= clk_fs;
end generate;


	------------------------------------------------------------------------------

	-- Active low reset
	axis_aresetn <= not rst;

	-- Output ports used to recognize transmit and receive transactions:
	--s_axis_adc_tready <= sig_s_axis_adc_tready;
	m_axis_dma_tvalid <= sig_m_axis_dma_tvalid;

	--m_axis_i0_data <= sig_fifo_stage2_AxC0_tdata(15 downto 0);
	--m_axis_i0_tvalid <= sig_m_axis_iq_tvalid;
	--m_axis_i0_tready <= sig_fifo_stage2_AxC0_tready;

	--m_axis_q0_data <= sig_fifo_stage2_AxC0_tdata(31 downto 16);
	--m_axis_q0_tvalid <= sig_m_axis_iq_tvalid;
	--m_axis_q0_tready <= sig_fifo_stage2_AxC0_tready;

	--m_axis_i1_data <= sig_fifo_stage2_AxC1_tdata(15 downto 0);
	--m_axis_i1_tvalid <= sig_m_axis_iq_tvalid;
	--m_axis_i1_tready <= sig_fifo_stage2_AxC1_tready;

	--m_axis_dma_data <= sig_fifo_stage2_AxC1_tdata(31 downto 0);
	--m_axis_dma_tvalid <= sig_m_axis_iq_tvalid;
	--m_axis_dma_tready <= sig_fifo_stage2_AxC1_tready;

	-- Recognize a reception transaction from the DMA
	adc_rx_transaction <= s_axis_adc_tvalid and sig_s_axis_adc_tready;
	-- Recognize a transmission towards the downstream module (CPRI Packer)
	downstream_tx_transaction <= sig_m_axis_dma_tvalid and m_axis_dma_tready;


--------------------------------------------------------------------------------
-- CASE #2: 2 AxC
--
--	             ->- Interface FIFO ->- Internal FIFO ->-
--              /                                         \
-- 	Demux --->-                                            ---- Mux -> Output
--              \                                         /
--               ->- Interface FIFO ->- Internal FIFO ->-
--
--------------------------------------------------------------------------------
two_AxC: if n_axc = 2 generate

	demux_commutator: process(clk_axi, rst)
	begin
		if (rst = '1') then
			demux_select <= (others => '0');
		elsif (rising_edge(clk_axi)) then
			if (adc_rx_transaction = '1') then
				if (demux_select = to_unsigned(n_axc - 1, 2)) then
					demux_select <= (others => '0');
				else
					demux_select <= demux_select + 1;
				end if;
			end if;
		end if;
	end process;


	mux_commutator: process(clk_axi, rst)
	begin
		if (rst = '1') then
			mux_select <= (others => '0');
		elsif (rising_edge(clk_axi)) then
			if (downstream_tx_transaction = '1') then
				if (mux_select = to_unsigned(n_axc - 1, 2)) then
					mux_select <= (others => '0');
				else
					mux_select <= mux_select + 1;
				end if;
			end if;
		end if;
	end process;

	------------------------
	-- Demultiplexer
	------------------------

	demux : stream_demux
	generic map(
		DATA_WIDTH => 32,
		USER_WIDTH => 96
	)
	port map(
		demux_selector => std_logic_vector(demux_select),
		-- Receive Stream: Axi Stream Slave
		RXD_S_AXIS_ACLK     => clk_axi  ,
		RXD_S_AXIS_ARESETN  => axis_aresetn,
		RXD_S_AXIS_TREADY   =>  open,
		RXD_S_AXIS_TDATA    => s_axis_adc_tdata ,
		RXD_S_AXIS_TLAST    => '0' ,
		RXD_S_AXIS_TVALID   => s_axis_adc_tvalid ,
		RXD_S_AXIS_TUSER    => (others => '0'),
		RXD_S_AXIS_TKEEP    => (others => '1'),
		-- Transmit Stream: Axi Stream Master 0
		RXD_M0_AXIS_TREADY  => sig_demux_AxC0_tready,
		RXD_M0_AXIS_TDATA   => sig_demux_AxC0_tdata,
		RXD_M0_AXIS_TLAST   => open ,
		RXD_M0_AXIS_TVALID  => sig_demux_AxC0_tvalid,
		RXD_M0_AXIS_TUSER   => open ,
		RXD_M0_AXIS_TKEEP   => open ,
		-- Transmit Stream: Axi Stream Master 1
		RXD_M1_AXIS_TREADY  => sig_demux_AxC1_tready,
		RXD_M1_AXIS_TDATA   => sig_demux_AxC1_tdata,
		RXD_M1_AXIS_TLAST   => open ,
		RXD_M1_AXIS_TVALID  => sig_demux_AxC1_tvalid,
		RXD_M1_AXIS_TUSER   => open ,
		RXD_M1_AXIS_TKEEP   => open ,
		-- Transmit Stream: Axi Stream Master 2
		RXD_M2_AXIS_TREADY  => '1',
		RXD_M2_AXIS_TDATA   => open ,
		RXD_M2_AXIS_TLAST   => open ,
		RXD_M2_AXIS_TVALID  => open ,
		RXD_M2_AXIS_TUSER   => open ,
		RXD_M2_AXIS_TKEEP   => open ,
		-- Transmit Stream: Axi Stream Master 3
		RXD_M3_AXIS_TREADY  => '1',
		RXD_M3_AXIS_TDATA   => open ,
		RXD_M3_AXIS_TLAST   => open ,
		RXD_M3_AXIS_TVALID  => open ,
		RXD_M3_AXIS_TUSER   => open ,
		RXD_M3_AXIS_TKEEP   => open
	);

	--------------
	--- AxC 0
	--------------

	-- Stage 1
	interface_fifo_axc_0 : fifo_axis_m_d64_w32_s_w32
	PORT MAP (
		m_aclk => used_clk,
		s_aclk => clk_axi,
		s_aresetn => axis_aresetn,
		s_axis_tvalid => sig_demux_AxC0_tvalid,
		s_axis_tready => sig_demux_AxC0_tready,
		s_axis_tdata => sig_demux_AxC0_tdata,
		m_axis_tvalid => sig_fifo_stage1_AxC0_tvalid,
		m_axis_tready => sig_fifo_stage1_AxC0_tready,
		m_axis_tdata => sig_fifo_stage1_AxC0_tdata,
		axis_overflow => open,
		axis_underflow => open
	);
	-- Stage 2
	internal_fifo_axc_0 : fifo_axis_m_d64_w32_s_w32
	PORT MAP (
		m_aclk => clk_axi,
		s_aclk => used_clk,
		s_aresetn => axis_aresetn,
		s_axis_tvalid => sig_fifo_stage1_AxC0_tvalid,
		s_axis_tready => sig_fifo_stage1_AxC0_tready,
		s_axis_tdata => sig_fifo_stage1_AxC0_tdata,
		m_axis_tvalid => sig_fifo_stage2_AxC0_tvalid,
		m_axis_tready => sig_fifo_stage2_AxC0_tready,
		m_axis_tdata => sig_fifo_stage2_AxC0_tdata,
		axis_overflow => open,
		axis_underflow => open
	);

	--------------
	--- AxC 1
	--------------

	-- Stage 1
	interface_fifo_axc_1 : fifo_axis_m_d64_w32_s_w32
	PORT MAP (
		m_aclk => used_clk,
		s_aclk => clk_axi,
		s_aresetn => axis_aresetn,
		s_axis_tvalid => sig_demux_AxC1_tvalid,
		s_axis_tready => sig_demux_AxC1_tready,
		s_axis_tdata => sig_demux_AxC1_tdata,
		m_axis_tvalid => sig_fifo_stage1_AxC1_tvalid,
		m_axis_tready => sig_fifo_stage1_AxC1_tready,
		m_axis_tdata => sig_fifo_stage1_AxC1_tdata,
		axis_overflow => open,
		axis_underflow => open
	);
	-- Stage 2
	internal_fifo_axc_1 : fifo_axis_m_d64_w32_s_w32
	PORT MAP (
		m_aclk => clk_axi,
		s_aclk => used_clk,
		s_aresetn => axis_aresetn,
		s_axis_tvalid => sig_fifo_stage1_AxC1_tvalid,
		s_axis_tready => sig_fifo_stage1_AxC1_tready,
		s_axis_tdata => sig_fifo_stage1_AxC1_tdata,
		m_axis_tvalid => sig_fifo_stage2_AxC1_tvalid,
		m_axis_tready => sig_fifo_stage2_AxC1_tready,
		m_axis_tdata => sig_fifo_stage2_AxC1_tdata,
		axis_overflow => open,
		axis_underflow => open
	);

	------------------------
	-- Multiplexer
	------------------------

	txMux : axis_mux
	port map(
		clk => clk_axi,
		aresetn => axis_aresetn,
		-- Selector
		selector => std_logic_vector(mux_select),
		-- Receive Stream 0
		s_axis_rx0_tready   => sig_fifo_stage2_AxC0_tready,
		s_axis_rx0_tdata    => sig_fifo_stage2_AxC0_tdata,
		s_axis_rx0_tvalid   => sig_fifo_stage2_AxC0_tvalid,
		-- Receive Stream 1
		s_axis_rx1_tready   => sig_fifo_stage2_AxC1_tready,
		s_axis_rx1_tdata    => sig_fifo_stage2_AxC1_tdata,
		s_axis_rx1_tvalid   => sig_fifo_stage2_AxC1_tvalid,
		-- Receive Stream 2
		s_axis_rx2_tready   => open,
		s_axis_rx2_tdata    => (others => '0'),
		s_axis_rx2_tvalid   => '0',
		-- Receive Stream 3
		s_axis_rx3_tready   => open,
		s_axis_rx3_tdata    => (others => '0'),
		s_axis_rx3_tvalid   => '0',
		-- Transmit Stream
		m_axis_tready  => m_axis_dma_tready,
		m_axis_tdata   => m_axis_dma_tdata,
		m_axis_tvalid  => sig_m_axis_dma_tvalid
	);

end generate;

end Behavioral;
