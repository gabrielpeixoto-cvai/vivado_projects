--------------------------------------------------------------------------------
-- Engineer: Igor Freire
--
-- Create Date:    02/19/2016
-- Module Name:    axis_mux - Behavioral
--
--  AXI Stream Multiplexer with select signal. Commutes a set of AXI-Stream
-- Inputs into a single AXI-Stream output.
--
--
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity axis_mux is
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
end axis_mux;

architecture Behavioral of axis_mux is
begin

  process(aresetn, selector, m_axis_tready, s_axis_rx0_tdata, s_axis_rx1_tdata,
    s_axis_rx2_tdata, s_axis_rx3_tdata, s_axis_rx0_tvalid, s_axis_rx1_tvalid,
    s_axis_rx2_tvalid, s_axis_rx3_tvalid)
  begin
    -- Default values
    s_axis_rx0_tready <= '0';
    s_axis_rx1_tready <= '0';
    s_axis_rx2_tready <= '0';
    s_axis_rx3_tready <= '0';

    if aresetn = '0' then
      s_axis_rx0_tready <= '0';
      s_axis_rx1_tready <= '0';
      s_axis_rx2_tready <= '0';
      s_axis_rx3_tready <= '0';
      m_axis_tdata      <= (others => '0');
      m_axis_tvalid     <= '0';
    else
      case selector is
      when "00" =>
        s_axis_rx0_tready <= m_axis_tready;
        m_axis_tdata      <= s_axis_rx0_tdata;
        m_axis_tvalid     <= s_axis_rx0_tvalid;
      when "01" =>
        s_axis_rx1_tready <= m_axis_tready;
        m_axis_tdata      <= s_axis_rx1_tdata;
        m_axis_tvalid     <= s_axis_rx1_tvalid;

      when "10" =>
        s_axis_rx2_tready <= m_axis_tready;
        m_axis_tdata      <= s_axis_rx2_tdata;
        m_axis_tvalid     <= s_axis_rx2_tvalid;

      when "11" =>
        s_axis_rx3_tready <= m_axis_tready;
        m_axis_tdata      <= s_axis_rx3_tdata;
        m_axis_tvalid     <= s_axis_rx3_tvalid;
      when others =>
        s_axis_rx0_tready <= '0';
        s_axis_rx1_tready <= '0';
        s_axis_rx2_tready <= '0';
        s_axis_rx3_tready <= '0';
        m_axis_tdata      <= (others => '0');
        m_axis_tvalid     <= '0';
      end case;
    end if;
  end process;

end Behavioral;

