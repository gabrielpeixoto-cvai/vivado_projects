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

entity tb_dac_dmaInterface is
end tb_dac_dmaInterface;

architecture STRUCTURE of tb_dac_dmaInterface is

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

	signal sig_dma_ready, sig_dma_valid : std_logic;
	signal sig_dma_data : std_logic_vector(31 downto 0);

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

	--sig_dma_data <= "11111111111111110000000000000000";
	--sig_dma_valid <= '1';
	sig_axis_axc0_itready<='1';
	sig_axis_axc0_qtready<='1';

	sig_axis_axc1_itready<='1';
	sig_axis_axc1_qtready<='1';

	dma_data_process:  process
		variable i0 : integer := 0;
		variable i1 : integer := 1;
		variable q0 : integer := 2;
		variable q1 : integer := 3;
	begin
		sig_dma_valid <= '0';
		sig_dma_data  <=  (others => '0');
		wait for 1 us;
		while true loop
			-- Align with clock
			wait until rising_edge(dac_clk);
			-- Simulate samples acquired by the ADC
			for i in 0 to 63 loop
				-- Increment
				i0 := i0 + 1;
				q0 := q0 + 2;
				sig_dma_valid <= '1';
				sig_dma_data(31 downto 16)  <=  std_logic_vector(to_unsigned(i0, 16));
				sig_dma_data(15 downto 0)  <=  std_logic_vector(to_unsigned(i0, 16));
				wait for dac_clk_period;
			end loop;
			sig_dma_valid <= '0';
			sig_dma_data  <=  (others => '0');
		end loop;
	end process;

	uut : dac_dmaInterface
	port map(
		clk_fs	=> dac_clk,
		clk_axi	=> axi_clk,
		rst			=> rst,

		s_axis_dma_tvalid	=> sig_dma_valid,
		s_axis_dma_tready	=> sig_dma_ready,
		s_axis_dma_tdata	=> sig_dma_data,

		m_axis_i0_tready	=> sig_axis_axc0_itready,
		m_axis_i0_tvalid	=> sig_axis_axc0_itvalid,
		m_axis_i0_tdata		=> sig_axis_axc0_itdata,

		m_axis_q0_tready	=> sig_axis_axc0_qtready,
		m_axis_q0_tvalid	=> sig_axis_axc0_qtvalid,
		m_axis_q0_tdata		=> sig_axis_axc0_qtdata,

		m_axis_i1_tready 	=> sig_axis_axc1_itready,
		m_axis_i1_tvalid	=> sig_axis_axc1_itvalid,
		m_axis_i1_tdata		=> sig_axis_axc1_itdata,

		m_axis_q1_tready 	=> sig_axis_axc1_qtready,
		m_axis_q1_tvalid	=> sig_axis_axc1_qtvalid,
		m_axis_q1_tdata		=> sig_axis_axc1_qtdata
	);

end architecture STRUCTURE;
