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
		axiClk : in std_logic;
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

	signal clk : std_logic := '0';
	signal rst : std_logic := '0';

	-- Clock period definitions
	constant axi_clk_period : time := 10 ns;
	constant dac_clk_period : time := 130.208 ns;
	signal axi_clk : std_logic := '0';
	signal dac_clk : std_logic := '0';


	-- Input AxC AXI streams
	signal sig_axis_axc0_itvalid, sig_axis_axc0_itready : std_logic;
	signal sig_axis_axc0_qtvalid, sig_axis_axc0_qtready : std_logic;
	signal sig_axis_axc0_itdata : std_logic_vector(15 downto 0);
	signal sig_axis_axc0_qtdata : std_logic_vector(15 downto 0);
	signal sig_axis_axc1_itvalid, sig_axis_axc1_itready : std_logic;
	signal sig_axis_axc1_qtvalid, sig_axis_axc1_qtready : std_logic;
	signal sig_axis_axc1_itdata : std_logic_vector(15 downto 0);
	signal sig_axis_axc1_qtdata : std_logic_vector(15 downto 0);

	signal sig_dac_i0data, sig_dac_q0data, sig_dac_i1data, sig_dac_q1data : std_logic_vector(15 downto 0);

	signal cpri_bf_in : std_logic_vector (127 downto 0);
	signal cpri_wr_en : std_logic := '0';

begin
	-- Clock process definitions
	clk_process : process
	begin
		dac_clk <= '0';
		wait for dac_clk_period/2;
		dac_clk <= '1';
		wait for dac_clk_period/2;
	end process;

	eth_clk_process : process
	begin
		axi_clk <= '0';
		wait for axi_clk_period/2;
		axi_clk <= '1';
		wait for axi_clk_period/2;
	end process;

	-- Generate resets
	rst_process : process
	begin
		rst <= '1';
		wait for axi_clk_period*10;
		rst <= '0';
		wait;
	end process;

	dac_read_process:  process
		variable i0 : integer := 0;
		variable i1 : integer := 1;
		variable q0 : integer := 2;
		variable q1 : integer := 3;
	begin
		sig_axis_axc0_itvalid <= '0';
		sig_axis_axc0_itdata  <=  (others => '0');
		sig_axis_axc0_qtvalid <= '0';
		sig_axis_axc0_qtdata  <=  (others => '0');
		sig_axis_axc1_itvalid <= '0';
		sig_axis_axc1_itdata  <=  (others => '0');
		sig_axis_axc1_qtvalid <= '0';
		sig_axis_axc1_qtdata  <=  (others => '0');
		wait for 1 us;
		while true loop
			-- Align with clock
			wait until rising_edge(dac_clk);
			-- Simulate samples acquired by the ADC
			for i in 0 to 63 loop
				-- Increment
				i0 := i0 + 1;
				i1 := i1 + 2;
				q0 := q0 + 3;
				q1 := q1 + 4;
				sig_axis_axc0_itvalid <= '1';
				sig_axis_axc0_itdata  <=  std_logic_vector(to_unsigned(i0, 16));
				sig_axis_axc0_qtvalid <= '1';
				sig_axis_axc0_qtdata  <=  std_logic_vector(to_unsigned(q0, 16));
				sig_axis_axc1_itvalid <= '1';
				sig_axis_axc1_itdata  <=  std_logic_vector(to_unsigned(i1, 16));
				sig_axis_axc1_qtvalid <= '1';
				sig_axis_axc1_qtdata  <=  std_logic_vector(to_unsigned(q1, 16));
				wait for dac_clk_period;
			end loop;
			sig_axis_axc0_itvalid <= '0';
			sig_axis_axc0_itdata  <=  (others => '0');
			sig_axis_axc0_qtvalid <= '0';
			sig_axis_axc0_qtdata  <=  (others => '0');
			sig_axis_axc1_itvalid <= '0';
			sig_axis_axc1_itdata  <=  (others => '0');
			sig_axis_axc1_qtvalid <= '0';
			sig_axis_axc1_qtdata  <=  (others => '0');
		end loop;
	end process;

	--sig_axis_axc0_itvalid	<= '1';
	--sig_axis_axc0_qtvalid	<= '1';
	--sig_axis_axc1_itvalid	<= '1';
	--sig_axis_axc1_qtvalid	<= '1';

	--sig_axis_axc0_itdata <= "1111111111111111";
	--sig_axis_axc0_qtdata <= "0000000000000000";
	--sig_axis_axc1_itdata <= "1111111111111111";
	--sig_axis_axc1_qtdata <= "0000000000000000";

	-- TODO use cpri_rx_full for something
	uut : dacInterface
	port map(
		-- Defaults
		dacClk  => dac_clk,
		axiClk  => axi_clk,
		rst  => rst,
		-- AXIS Input
		-- AxC 0
		s_axis_axc0_i_tready 	=> sig_axis_axc0_itready,
		s_axis_axc0_i_tvalid 	=> sig_axis_axc0_itvalid,
		s_axis_axc0_i_tdata  	=> sig_axis_axc0_itdata,
		s_axis_axc0_q_tready 	=> sig_axis_axc0_qtready,
		s_axis_axc0_q_tvalid 	=> sig_axis_axc0_qtvalid,
		s_axis_axc0_q_tdata  	=> sig_axis_axc0_qtdata,
		-- AxC 1
		s_axis_axc1_i_tready 	=> sig_axis_axc1_itready,
		s_axis_axc1_i_tvalid	=> sig_axis_axc1_itvalid,
		s_axis_axc1_i_tdata  	=> sig_axis_axc1_itdata,
		s_axis_axc1_q_tready 	=> sig_axis_axc1_qtready,
		s_axis_axc1_q_tvalid 	=> sig_axis_axc1_qtvalid,
		s_axis_axc1_q_tdata		=> sig_axis_axc1_qtdata,
		-- AD9361 input bus
		tx_i0_valid   => '1',
		tx_i0_enable  => '1',
		tx_i0_data    => sig_dac_i0data,
		tx_q0_valid   => '1',
		tx_q0_enable  => '1',
		tx_q0_data    => sig_dac_q0data,
		tx_i1_valid   => '1' ,
		tx_i1_enable  => '1',
		tx_i1_data    => sig_dac_i1data,
		tx_q1_valid   => '1',
		tx_q1_enable  => '1',
		tx_q1_data    => sig_dac_q1data,
		-- Interrupt
		clkCtrlInterrupt => open,
		-- Interrupt Status
		clkCtrlInterruptInfo => open
	);

end architecture STRUCTURE;
