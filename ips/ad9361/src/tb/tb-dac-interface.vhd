-------------------------------------------------------------------------------
-- cpu_subsystem_top.vhd
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
USE ieee.numeric_std.ALL;

entity tb_dacInterface is
end tb_dacInterface;

architecture STRUCTURE of tb_dacInterface is

	component dacInterface is
	port(
		dacClk : in std_logic;
		ethClk : in std_logic;
		rst : in std_logic;
		-- AXIS Input
		-- AxC 0
		s_axis_axc0_tready : out std_logic;
		s_axis_axc0_tvalid : in  std_logic;
		s_axis_axc0_tdata  : in  std_logic_vector(31 downto 0);
		-- AxC 1
		s_axis_axc1_tready : out std_logic;
		s_axis_axc1_tvalid : in  std_logic;
		s_axis_axc1_tdata  : in  std_logic_vector(31 downto 0);
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

	signal clk : std_logic := '0';
	signal rst : std_logic := '0';

	-- Clock period definitions
	constant eth_clk_period : time := 10 ns;
	constant da_rd_clk_period : time := 130.208 ns;
	signal eth_clk : std_logic := '0';
	signal da_rd_clk : std_logic := '0';


	-- Input AxC AXI streams
	signal sig_axis_axc0_tvalid, sig_axis_axc0_tready : std_logic;
	signal sig_axis_axc0_tdata : std_logic_vector(31 downto 0);
	signal sig_axis_axc1_tvalid, sig_axis_axc1_tready : std_logic;
	signal sig_axis_axc1_tdata : std_logic_vector(31 downto 0);

	signal cpri_bf_in : std_logic_vector (127 downto 0);
	signal cpri_wr_en : std_logic := '0';

begin
	-- Clock process definitions
	clk_process : process
	begin
		da_rd_clk <= '0';
		wait for da_rd_clk_period/2;
		da_rd_clk <= '1';
		wait for da_rd_clk_period/2;
	end process;

	eth_clk_process : process
	begin
		eth_clk <= '0';
		wait for eth_clk_period/2;
		eth_clk <= '1';
		wait for eth_clk_period/2;
	end process;

	-- Generate resets
	rst_process : process
	begin
		rst <= '1';
		wait for eth_clk_period*10;
		rst <= '0';
		wait;
	end process;

	----------------------------------
	-- CPRI BF Rx process
	----------------------------------
	-- In the cpriEthernetInterface module, the incoming Ethernet data
	-- comes in words of 32 bit. Hence, one BF of 128 bits takes
	-- 4 clock cycles to be buffered. Then, since one BF carries
	-- 8 samples (4 IQ) and there are 4 queues being read by the
	-- DAC (2 IQ channels), then it takes 2 DAC clock cycles to
	-- read a BF.
	-- Based on these values, one Ethernet packet with 64 BFs
	-- takes 2*64 CPRI clock cycles to be procesed (buffered).
	-- For a CPRI clock of 7.68MHz (period of 0.1302 us), this
	-- corresponds to 16.6667us
	cpri_bf_rx_process:  process
		variable i0 : integer := 0;
		variable i1 : integer := 0;
		variable q0 : integer := 0;
		variable q1 : integer := 0;
	begin
		cpri_wr_en <= '0';
		wait for 5 us;
		while true loop
			for j in 0 to 2 loop -- alternating Eth packet period
				if (j = 0) then
					wait for (16.66 - 2.56)*1 us;
				else
					wait for (16.67 - 2.56)*1 us;
				end if;
				-- Align with clock
				wait until rising_edge(eth_clk);
				-- Buffer the 64 BFs contained in the Eth packet
				for i in 0 to 63 loop
					-- First IQ samples for each AxC
					sig_axis_axc0_tdata <= std_logic_vector(to_unsigned(i0, 15)) & '0' & std_logic_vector(to_unsigned(q0, 15)) & '0';
					sig_axis_axc1_tdata <= std_logic_vector(to_unsigned(i1, 15)) & '0' & std_logic_vector(to_unsigned(q1, 15)) & '0';
					sig_axis_axc0_tvalid <= '1';
					sig_axis_axc1_tvalid <= '1';
					-- Enable buffering only at the 4th clock cycle
					-- which is the time necessary to aquire 128 bits via
					-- the Ethernet interface
					wait for eth_clk_period;
					-- Second IQ samples for each AxC
					sig_axis_axc0_tdata <= std_logic_vector(to_unsigned(i0+1, 15)) & '0' & std_logic_vector(to_unsigned(q0+1, 15)) & '0';
					sig_axis_axc1_tdata <= std_logic_vector(to_unsigned(i1+1, 15)) & '0' & std_logic_vector(to_unsigned(q1+1, 15)) & '0';
					sig_axis_axc0_tvalid <= '1';
					sig_axis_axc1_tvalid <= '1';
					-- Increment
					i0 := i0 + 2;
					i1 := i1 + 2;
					q0 := q0 + 2;
					q1 := q1 + 2;
					wait for eth_clk_period;
					sig_axis_axc0_tdata  <= (others=>'0');
					sig_axis_axc1_tdata  <= (others=>'0');
					sig_axis_axc0_tvalid <= '0';
					sig_axis_axc1_tvalid <= '0';
					wait for 2*eth_clk_period;
				end loop;
				cpri_wr_en <= '0';
				cpri_bf_in <= (others=>'0');
			end loop;
		end loop;
	end process;

	-- TODO use cpri_rx_full for something
	uut : dacInterface
	port map(
		-- Defaults
		dacClk  => da_rd_clk,
		ethClk  => eth_clk,
		rst  => rst,
		-- AXIS Input
		-- AxC 0
		s_axis_axc0_tready => open,
		s_axis_axc0_tvalid => sig_axis_axc0_tvalid,
		s_axis_axc0_tdata  => sig_axis_axc0_tdata,
		-- AxC 1
		s_axis_axc1_tready => open,
		s_axis_axc1_tvalid => sig_axis_axc1_tvalid,
		s_axis_axc1_tdata  => sig_axis_axc1_tdata,
		-- AD9361 input bus
		tx_i0_valid   => '1',
		tx_i0_enable  => '1',
		tx_i0_data    => open,
		tx_q0_valid   => '1',
		tx_q0_enable  => '1',
		tx_q0_data    => open,
		tx_i1_valid   => '1' ,
		tx_i1_enable  => '1',
		tx_i1_data    => open,
		tx_q1_valid   => '1',
		tx_q1_enable  => '1',
		tx_q1_data    => open,
		-- Interrupt
		clkCtrlInterrupt => open,
		-- Interrupt Status
		clkCtrlInterruptInfo => open
	);

end architecture STRUCTURE;