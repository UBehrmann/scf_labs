------------------------------------------------------------------------------
-- AXI4-Lite slave TEMPLATE — copy labo5 axi4lite_slave.vhd as base, then:
--   1. Keep EMI handshake processes (aw/w/ar channels) unchanged
--   2. Replace user register case statements with map below
--   3. Instantiate conv_engine + line buffers / FIFOs in marked sections
--
-- Register map (word index = axi_awaddr_mem / 4):
--   0 RO  constant  x"D06512ED"
--   1 RW  test
--   2 W31 reset cmd, R[9:0] status
--   3-5 RW kernel columns (3 x int8)
--   6 RO  max_width
--   7 RW  image width
--   8 WO  data_in (4 pixels)
--   9 RO  data_out (pop FIFO on read)
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi4lite_slave is
    generic (
        AXI_DATA_WIDTH : integer := 32;
        AXI_ADDR_WIDTH : integer := 12
    );
    port (
        clk_i         : in  std_logic;
        reset_i       : in  std_logic;
        axi_awaddr_i  : in  std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
        axi_awprot_i  : in  std_logic_vector(2 downto 0);
        axi_awvalid_i : in  std_logic;
        axi_awready_o : out std_logic;
        axi_wdata_i   : in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
        axi_wstrb_i   : in  std_logic_vector((AXI_DATA_WIDTH / 8) - 1 downto 0);
        axi_wvalid_i  : in  std_logic;
        axi_wready_o  : out std_logic;
        axi_bresp_o   : out std_logic_vector(1 downto 0);
        axi_bvalid_o  : out std_logic;
        axi_bready_i  : in  std_logic;
        axi_araddr_i  : in  std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
        axi_arprot_i  : in  std_logic_vector(2 downto 0);
        axi_arvalid_i : in  std_logic;
        axi_arready_o : out std_logic;
        axi_rdata_o   : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
        axi_rresp_o   : out std_logic_vector(1 downto 0);
        axi_rvalid_o  : out std_logic;
        axi_rready_i  : in  std_logic
    );
end entity axi4lite_slave;

architecture rtl of axi4lite_slave is
    constant ADDR_LSB : integer := (AXI_DATA_WIDTH / 32) + 1;

    -- TODO: copy full AXI FSM signals from labo5/axi4lite_slave.vhd
    signal tie_low : std_logic := '0';

begin
    axi_awready_o <= tie_low;
    axi_wready_o  <= tie_low;
    axi_bvalid_o  <= tie_low;
    axi_bresp_o   <= (others => '0');
    axi_arready_o <= tie_low;
    axi_rvalid_o  <= tie_low;
    axi_rresp_o   <= (others => '0');
    axi_rdata_o   <= (others => '0');

    -- TODO: datapath between REG_DATA_IN and REG_DATA_OUT
end architecture rtl;
