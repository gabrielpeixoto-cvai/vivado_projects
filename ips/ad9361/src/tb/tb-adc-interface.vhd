library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
USE ieee.numeric_std.ALL;

entity tb_adcInterface is
end tb_adcInterface;

architecture STRUCTURE of tb_adcInterface is

	component adcInterface is
	generic(
		n_axc : integer := 2
	);
	port(
		-- Defaults
		adcClk : in std_logic;
		axiClk  : in std_logic;
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
	end component;

	signal clk : std_logic := '0';
	signal rst : std_logic := '0';

	-- Clock period definitions
	constant axi_clk_period : time := 10 ns;
	constant adc_clk_period : time := 130.208 ns;
	signal axi_clk : std_logic := '0';
	signal adc_clk : std_logic := '0';


	signal sig_rx_i0_valid   : std_logic;
	signal sig_rx_i0_data    : std_logic_vector(15 downto 0);
	signal sig_rx_q0_valid   : std_logic;
	signal sig_rx_q0_data    : std_logic_vector(15 downto 0);
	signal sig_rx_i1_valid   : std_logic;
	signal sig_rx_i1_data    : std_logic_vector(15 downto 0);
	signal sig_rx_q1_valid   : std_logic;
	signal sig_rx_q1_data    : std_logic_vector(15 downto 0);

begin
	-- Clock process definitions
	clk_process : process
	begin
		adc_clk <= '0';
		wait for adc_clk_period/2;
		adc_clk <= '1';
		wait for adc_clk_period/2;
	end process;

	axi_clk_process : process
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

	adc_acquisition_process:  process
		variable i0 : integer := 0;
		variable i1 : integer := 1;
		variable q0 : integer := 2;
		variable q1 : integer := 3;
	begin
		sig_rx_i0_valid <= '0';
		sig_rx_i0_data  <=  (others => '0');
		sig_rx_q0_valid <= '0';
		sig_rx_q0_data  <=  (others => '0');
		sig_rx_i1_valid <= '0';
		sig_rx_i1_data  <=  (others => '0');
		sig_rx_q1_valid <= '0';
		sig_rx_q1_data  <=  (others => '0');
		wait for 1 us;
		while true loop
			-- Align with clock
			wait until rising_edge(adc_clk);
			-- Simulate samples acquired by the ADC
			for i in 0 to 63 loop
				-- Increment
				i0 := i0 + 1;
				i1 := i1 + 2;
				q0 := q0 + 3;
				q1 := q1 + 4;
				sig_rx_i0_valid <= '1';
				sig_rx_i0_data  <=  std_logic_vector(to_unsigned(i0, 16));
				sig_rx_q0_valid <= '1';
				sig_rx_q0_data  <=  std_logic_vector(to_unsigned(q0, 16));
				sig_rx_i1_valid <= '1';
				sig_rx_i1_data  <=  std_logic_vector(to_unsigned(i1, 16));
				sig_rx_q1_valid <= '1';
				sig_rx_q1_data  <=  std_logic_vector(to_unsigned(q1, 16));
				wait for adc_clk_period;
			end loop;
			sig_rx_i0_valid <= '0';
			sig_rx_i0_data  <=  (others => '0');
			sig_rx_q0_valid <= '0';
			sig_rx_q0_data  <=  (others => '0');
			sig_rx_i1_valid <= '0';
			sig_rx_i1_data  <=  (others => '0');
			sig_rx_q1_valid <= '0';
			sig_rx_q1_data  <=  (others => '0');
		end loop;
	end process;

	uut : adcInterface
	port map(
		-- Defaults
		adcClk  => adc_clk,
		axiClk  => axi_clk,
		rst  => rst,
		-- AD9361 input bus
		rx_i0_valid   => sig_rx_i0_valid,
		rx_i0_enable  => '1',
		rx_i0_data    => sig_rx_i0_data,
		rx_q0_valid   => sig_rx_q0_valid,
		rx_q0_enable  => '1',
		rx_q0_data    => sig_rx_q0_data,
		rx_i1_valid   => sig_rx_i1_valid,
		rx_i1_enable  => '1',
		rx_i1_data    => sig_rx_i1_data,
		rx_q1_valid   => sig_rx_q1_valid,
		rx_q1_enable  => '1',
		rx_q1_data    => sig_rx_q1_data,
		m_axis_iq_tready => '1',
		m_axis_iq_tvalid => open,
		m_axis_iq_tdata  => open
	);

end architecture STRUCTURE;