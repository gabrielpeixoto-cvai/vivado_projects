--------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    20:53:06 04/14/2015
-- Design Name:
-- Module Name:    top - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
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

entity stream_demux is
	generic(
		DATA_WIDTH : integer := 32;
		USER_WIDTH : integer := 96
	);
	port (
		-- Selector
		demux_selector: in STD_LOGIC_VECTOR(1 downto 0);

		-- Receive Stream	: Axi Stream Slave
		RXD_S_AXIS_ACLK 	: in  STD_LOGIC;
		RXD_S_AXIS_ARESETN 	: in  STD_LOGIC;
		RXD_S_AXIS_TREADY 	: out  STD_LOGIC;
		RXD_S_AXIS_TDATA 	: in  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
		RXD_S_AXIS_TLAST 	: in  STD_LOGIC;
		RXD_S_AXIS_TVALID 	: in  STD_LOGIC;
		RXD_S_AXIS_TUSER 	: in  STD_LOGIC_VECTOR (USER_WIDTH-1 downto 0);
		RXD_S_AXIS_TKEEP 	: in  STD_LOGIC_VECTOR ((DATA_WIDTH/8)-1 downto 0);

		-- Transmit Stream	: Axi Stream Master 0
		RXD_M0_AXIS_TREADY 	: in  STD_LOGIC;
		RXD_M0_AXIS_TDATA 	: out  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
		RXD_M0_AXIS_TLAST 	: out  STD_LOGIC;
		RXD_M0_AXIS_TVALID 	: out  STD_LOGIC;
		RXD_M0_AXIS_TUSER 	: out  STD_LOGIC_VECTOR (USER_WIDTH-1 downto 0);
		RXD_M0_AXIS_TKEEP 	: out  STD_LOGIC_VECTOR ((DATA_WIDTH/8)-1 downto 0);

		-- Transmit Stream	: Axi Stream Master 1
		RXD_M1_AXIS_TREADY 	: in  STD_LOGIC;
		RXD_M1_AXIS_TDATA 	: out  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
		RXD_M1_AXIS_TLAST 	: out  STD_LOGIC;
		RXD_M1_AXIS_TVALID 	: out  STD_LOGIC;
		RXD_M1_AXIS_TUSER 	: out  STD_LOGIC_VECTOR (USER_WIDTH-1 downto 0);
		RXD_M1_AXIS_TKEEP 	: out  STD_LOGIC_VECTOR ((DATA_WIDTH/8)-1 downto 0);

		-- Transmit Stream	: Axi Stream Master 2
		RXD_M2_AXIS_TREADY 	: in  STD_LOGIC;
		RXD_M2_AXIS_TDATA 	: out  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
		RXD_M2_AXIS_TLAST 	: out  STD_LOGIC;
		RXD_M2_AXIS_TVALID 	: out  STD_LOGIC;
		RXD_M2_AXIS_TUSER 	: out  STD_LOGIC_VECTOR (USER_WIDTH-1 downto 0);
		RXD_M2_AXIS_TKEEP 	: out  STD_LOGIC_VECTOR ((DATA_WIDTH/8)-1 downto 0);

		-- Transmit Stream	: Axi Stream Master 3
		RXD_M3_AXIS_TREADY 	: in  STD_LOGIC;
		RXD_M3_AXIS_TDATA 	: out  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
		RXD_M3_AXIS_TLAST 	: out  STD_LOGIC;
		RXD_M3_AXIS_TVALID 	: out  STD_LOGIC;
		RXD_M3_AXIS_TUSER 	: out  STD_LOGIC_VECTOR (USER_WIDTH-1 downto 0);
		RXD_M3_AXIS_TKEEP 	: out  STD_LOGIC_VECTOR ((DATA_WIDTH/8)-1 downto 0)
	);
end stream_demux;

architecture Behavioral of stream_demux is
begin

	RXD_S_AXIS_TREADY  <= '0' when RXD_S_AXIS_ARESETN = '0' else
		RXD_M0_AXIS_TREADY  when demux_selector = "00" else
		RXD_M1_AXIS_TREADY  when demux_selector = "01" else
		RXD_M2_AXIS_TREADY  when demux_selector = "10" else
		RXD_M3_AXIS_TREADY  when demux_selector = "11";

	process(demux_selector, RXD_S_AXIS_ARESETN, RXD_S_AXIS_TDATA,
		RXD_S_AXIS_TLAST, RXD_S_AXIS_TVALID, RXD_S_AXIS_TUSER, RXD_S_AXIS_TKEEP)
	begin
		if RXD_S_AXIS_ARESETN = '0' then
			RXD_M0_AXIS_TDATA  <= (others => '0');
			RXD_M0_AXIS_TLAST  <= '0';
			RXD_M0_AXIS_TVALID <= '0';
			RXD_M0_AXIS_TUSER  <= (others => '0');
			RXD_M0_AXIS_TKEEP  <= (others => '0');
			RXD_M1_AXIS_TDATA  <= (others => '0');
			RXD_M1_AXIS_TLAST  <= '0';
			RXD_M1_AXIS_TVALID <= '0';
			RXD_M1_AXIS_TUSER  <= (others => '0');
			RXD_M1_AXIS_TKEEP  <= (others => '0');
			RXD_M2_AXIS_TDATA  <= (others => '0');
			RXD_M2_AXIS_TLAST  <= '0';
			RXD_M2_AXIS_TVALID <= '0';
			RXD_M2_AXIS_TUSER  <= (others => '0');
			RXD_M2_AXIS_TKEEP  <= (others => '0');
			RXD_M3_AXIS_TDATA  <= (others => '0');
			RXD_M3_AXIS_TLAST  <= '0';
			RXD_M3_AXIS_TVALID <= '0';
			RXD_M3_AXIS_TUSER  <= (others => '0');
			RXD_M3_AXIS_TKEEP  <= (others => '0');
		else
			case demux_selector is
			when "00" =>
				RXD_S_AXIS_TREADY  <= '1';
				RXD_M0_AXIS_TDATA  <= RXD_S_AXIS_TDATA ;
				RXD_M0_AXIS_TLAST  <= RXD_S_AXIS_TLAST ;
				RXD_M0_AXIS_TVALID <= RXD_S_AXIS_TVALID;
				RXD_M0_AXIS_TUSER  <= RXD_S_AXIS_TUSER ;
				RXD_M0_AXIS_TKEEP  <= RXD_S_AXIS_TKEEP ;
				RXD_M1_AXIS_TDATA  <= (others => '0');
				RXD_M1_AXIS_TLAST  <= '0';
				RXD_M1_AXIS_TVALID <= '0';
				RXD_M1_AXIS_TUSER  <= (others => '0');
				RXD_M1_AXIS_TKEEP  <= (others => '0');
				RXD_M2_AXIS_TDATA  <= (others => '0');
				RXD_M2_AXIS_TLAST  <= '0';
				RXD_M2_AXIS_TVALID <= '0';
				RXD_M2_AXIS_TUSER  <= (others => '0');
				RXD_M2_AXIS_TKEEP  <= (others => '0');
				RXD_M3_AXIS_TDATA  <= (others => '0');
				RXD_M3_AXIS_TLAST  <= '0';
				RXD_M3_AXIS_TVALID <= '0';
				RXD_M3_AXIS_TUSER  <= (others => '0');
				RXD_M3_AXIS_TKEEP  <= (others => '0');
			when "01" =>
				RXD_S_AXIS_TREADY  <= '1';
				RXD_M0_AXIS_TDATA  <= (others => '0');
				RXD_M0_AXIS_TLAST  <= '0';
				RXD_M0_AXIS_TVALID <= '0';
				RXD_M0_AXIS_TUSER  <= (others => '0');
				RXD_M0_AXIS_TKEEP  <= (others => '0');
				RXD_M1_AXIS_TDATA  <= RXD_S_AXIS_TDATA ;
				RXD_M1_AXIS_TLAST  <= RXD_S_AXIS_TLAST ;
				RXD_M1_AXIS_TVALID <= RXD_S_AXIS_TVALID;
				RXD_M1_AXIS_TUSER  <= RXD_S_AXIS_TUSER ;
				RXD_M1_AXIS_TKEEP  <= RXD_S_AXIS_TKEEP ;
				RXD_M2_AXIS_TDATA  <= (others => '0');
				RXD_M2_AXIS_TLAST  <= '0';
				RXD_M2_AXIS_TVALID <= '0';
				RXD_M2_AXIS_TUSER  <= (others => '0');
				RXD_M2_AXIS_TKEEP  <= (others => '0');
				RXD_M3_AXIS_TDATA  <= (others => '0');
				RXD_M3_AXIS_TLAST  <= '0';
				RXD_M3_AXIS_TVALID <= '0';
				RXD_M3_AXIS_TUSER  <= (others => '0');
				RXD_M3_AXIS_TKEEP  <= (others => '0');
			when "10" =>
				RXD_S_AXIS_TREADY  <= '1';
				RXD_M0_AXIS_TDATA  <= (others => '0');
				RXD_M0_AXIS_TLAST  <= '0';
				RXD_M0_AXIS_TVALID <= '0';
				RXD_M0_AXIS_TUSER  <= (others => '0');
				RXD_M0_AXIS_TKEEP  <= (others => '0');
				RXD_M1_AXIS_TDATA  <= (others => '0');
				RXD_M1_AXIS_TLAST  <= '0';
				RXD_M1_AXIS_TVALID <= '0';
				RXD_M1_AXIS_TUSER  <= (others => '0');
				RXD_M1_AXIS_TKEEP  <= (others => '0');
				RXD_M2_AXIS_TDATA  <= RXD_S_AXIS_TDATA ;
				RXD_M2_AXIS_TLAST  <= RXD_S_AXIS_TLAST ;
				RXD_M2_AXIS_TVALID <= RXD_S_AXIS_TVALID;
				RXD_M2_AXIS_TUSER  <= RXD_S_AXIS_TUSER ;
				RXD_M2_AXIS_TKEEP  <= RXD_S_AXIS_TKEEP ;
				RXD_M3_AXIS_TDATA  <= (others => '0');
				RXD_M3_AXIS_TLAST  <= '0';
				RXD_M3_AXIS_TVALID <= '0';
				RXD_M3_AXIS_TUSER  <= (others => '0');
				RXD_M3_AXIS_TKEEP  <= (others => '0');
			when "11" =>
				RXD_S_AXIS_TREADY  <= '1';
				RXD_M0_AXIS_TDATA  <= (others => '0');
				RXD_M0_AXIS_TLAST  <= '0';
				RXD_M0_AXIS_TVALID <= '0';
				RXD_M0_AXIS_TUSER  <= (others => '0');
				RXD_M0_AXIS_TKEEP  <= (others => '0');
				RXD_M1_AXIS_TDATA  <= (others => '0');
				RXD_M1_AXIS_TLAST  <= '0';
				RXD_M1_AXIS_TVALID <= '0';
				RXD_M1_AXIS_TUSER  <= (others => '0');
				RXD_M1_AXIS_TKEEP  <= (others => '0');
				RXD_M2_AXIS_TDATA  <= (others => '0');
				RXD_M2_AXIS_TLAST  <= '0';
				RXD_M2_AXIS_TVALID <= '0';
				RXD_M2_AXIS_TUSER  <= (others => '0');
				RXD_M2_AXIS_TKEEP  <= (others => '0');
				RXD_M3_AXIS_TDATA  <= RXD_S_AXIS_TDATA ;
				RXD_M3_AXIS_TLAST  <= RXD_S_AXIS_TLAST ;
				RXD_M3_AXIS_TVALID <= RXD_S_AXIS_TVALID;
				RXD_M3_AXIS_TUSER  <= RXD_S_AXIS_TUSER ;
				RXD_M3_AXIS_TKEEP  <= RXD_S_AXIS_TKEEP ;
			when others =>
				RXD_S_AXIS_TREADY  <= '1';
				RXD_M0_AXIS_TDATA  <= (others => '0');
				RXD_M0_AXIS_TLAST  <= '0';
				RXD_M0_AXIS_TVALID <= '0';
				RXD_M0_AXIS_TUSER  <= (others => '0');
				RXD_M0_AXIS_TKEEP  <= (others => '0');
				RXD_M1_AXIS_TDATA  <= (others => '0');
				RXD_M1_AXIS_TLAST  <= '0';
				RXD_M1_AXIS_TVALID <= '0';
				RXD_M1_AXIS_TUSER  <= (others => '0');
				RXD_M1_AXIS_TKEEP  <= (others => '0');
				RXD_M2_AXIS_TDATA  <= (others => '0');
				RXD_M2_AXIS_TLAST  <= '0';
				RXD_M2_AXIS_TVALID <= '0';
				RXD_M2_AXIS_TUSER  <= (others => '0');
				RXD_M2_AXIS_TKEEP  <= (others => '0');
				RXD_M3_AXIS_TDATA  <= (others => '0');
				RXD_M3_AXIS_TLAST  <= '0';
				RXD_M3_AXIS_TVALID <= '0';
				RXD_M3_AXIS_TUSER  <= (others => '0');
				RXD_M3_AXIS_TKEEP  <= (others => '0');
			end case;
		end if;
	end process;

end Behavioral;
