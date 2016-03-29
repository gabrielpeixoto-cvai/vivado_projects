--------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    14:20:58 03/23/2015
-- Design Name:
-- Module Name:    ADC Interface - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Outputs I and Q samples received from the ADC through a single outboud AXIS
-- interface. Each AxC takes one turn among the "bursts" of AXIS transmissions.
-- For example, if there are 2 AxC in the system, 2 AXIS 32-bit words are trans-
-- mitted downstream in each "burst", the first carrying the IQ sample for AxC0
-- and the second carrying the IQ sample for AxC1. This is because the RoE
-- system maps the AxC with lowest index into the least significant portion of
-- the the Basic Frames, so this module outputs them first.
--
-- Regarding clock domains, this module receives IQ samples in the clock domain
-- of the ADC, but outputs them in the faster AXI clock (100 MHz), as soon as
-- they are ready. The output is validated every time the number of samples
-- acquired in the buffer is at least the number of AxC in the system.
--
-- It should be noted that when compression is being used in the system, the DAC
-- is assumed to acquire samples faster in comparison to the rate of samples in
-- the output of the compressor module (following the ADC Interface). The number
-- of CPRI clock cycles required to form a BF still corresponds to the
-- oversampling ratio of the DAC sampling frequency with respect to the chip
-- rate. The difference is that the line rate option word width can be scaled
-- down by the compression ratio. For example, for 2 LTE 20MHz AxC (fs = 30.72
-- MHz), the oversampling ratio is 8, so that a CPRI BF shall be formed in 8
-- clock cycles. After 8 clock cycles, 8 x 2 = 16 words of 32 bits are
-- accumulated in the compressor. Without compression, line rate option #3 (with
-- 4 bytes per word) would be required to transport this bandwidth. In contrast,
-- assuming a compression ratio of 4, during this interval of 8 clock cycles the
-- compressor receives 512 bits and outputs 128 bits, so that by truncating each
-- IQ sample to 30 bit as usual, line rate option #1 can be used instead (line
-- rate option word width of 4 bytes was scaled down by 4 to 1 byte). The user
-- of the RoE Core is required to choose the line rate option properly when
-- compression is enabled in the system.
--
-- Note: the RoE system puts the quadrature ("Q") part of the IQ samples in the
-- MSB portion and the In-Phase ("I") in the LSB. Secondly,
--
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity adcInterface is
	generic(
		n_axc : integer := 2
	);
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

		-- Output of IQ samples through AXIS bus
		m_axis_iq_tready : in std_logic;
		m_axis_iq_tvalid : out std_logic;
		m_axis_iq_tdata  : out std_logic_vector(31 downto 0)
	);
end adcInterface;

architecture Behavioral of adcInterface is

	COMPONENT adc_interface_fifo
	  PORT (
	    rst : IN STD_LOGIC;
	    wr_clk : IN STD_LOGIC;
	    rd_clk : IN STD_LOGIC;
	    din : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
	    wr_en : IN STD_LOGIC;
	    rd_en : IN STD_LOGIC;
	    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
	    full : OUT STD_LOGIC;
	    empty : OUT STD_LOGIC;
	    rd_data_count : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	    wr_data_count : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
	  );
	END COMPONENT;

	-- FSM that controls the reading of samples buffered from the ADC
	type state_type is (IDLE, PREP_READ, TRANSMIT);
	signal state : state_type := IDLE;

	-- Flag when each I and Q are acquired
	signal axc0_i_acquired : std_logic;
	signal axc0_q_acquired : std_logic;
	signal axc1_i_acquired : std_logic;
	signal axc1_q_acquired : std_logic;
	signal all_axc_samples_acquired : std_logic;

	-- Enable read from FIFO
	signal fifo_rd_en : std_logic;
	-- Signal for internal read Data count:
	signal n_iq_samples_ready : std_logic_vector(7 downto 0);
begin

	-- IQ data received from the ADC is buffered
	-- Note the FIFO is read with 32-bit and written with 64 bit. Then, because
	-- the FIFO implementation is such that the 32 MSB within the 64 are read
	-- first, the AxC0 IQ sample is written into the 32 MSB.
	fifo_cpriBFs : adc_interface_fifo
	port map (
		rst  	=> rst,
		wr_clk  => adcClk,
		rd_clk  => axiClk,
		din  	=> rx_q0_data & rx_i0_data & rx_q1_data & rx_i1_data,
		wr_en  	=> all_axc_samples_acquired,
		rd_en  	=> fifo_rd_en,
		dout  	=> m_axis_iq_tdata,
		full  	=> open,
		empty  	=> open,
		rd_data_count  => n_iq_samples_ready,
		wr_data_count  => open
	);

	-- A flag is asserted every time a new I or Q sample is acquired.
	axc0_i_acquired <= rx_i0_enable and rx_i0_valid;
	axc0_q_acquired <= rx_q0_enable and rx_q0_valid;
	axc1_i_acquired <= rx_i1_enable and rx_i1_valid;
	axc1_q_acquired <= rx_q1_enable and rx_q1_valid;

	-- When all AxC samples are concurrently acquired for acquisition
	all_axc_samples_acquired <= axc0_i_acquired and axc0_q_acquired and
							axc1_i_acquired and axc1_q_acquired;


	-- Control the interleaved transmission of IQ samples within a sigle
	-- outbound AXIS bus through the following state machine:
	interleaver_StateControl : process(axiClk, rst)
	begin
		if (rst = '1') then
			state <= IDLE;
		elsif (rising_edge(axiClk)) then
			case state is
				when IDLE =>
					if(unsigned(n_iq_samples_ready) >= n_axc
						and m_axis_iq_tready = '1') then
						state <= PREP_READ;
					else
						state <= IDLE;
					end if;
				when PREP_READ =>
					-- Prepare for reading the buffer
					state <= TRANSMIT;
				when TRANSMIT =>
					if (unsigned(n_iq_samples_ready) < n_axc) then
						state <= IDLE;
					end if;
			end case;
		end if;
	end process;

	-- The interleaved output of AxC samples is accomplished simply by reading
	-- from the buffer. Note the "read enable" has to be asserted one clock
	-- cycle before the actual read.
	interleaver_OutputLogic : process(state)
	begin
		case state is
			when IDLE =>
				m_axis_iq_tvalid <= '0';
				fifo_rd_en <= '0';
			when PREP_READ =>
				m_axis_iq_tvalid <= '0';
				fifo_rd_en <= '1';
			when TRANSMIT =>
				-- Keep reading while the downstream module is ready
				fifo_rd_en <= m_axis_iq_tready;
				m_axis_iq_tvalid <= '1';
		end case;
	end process;

end Behavioral;
