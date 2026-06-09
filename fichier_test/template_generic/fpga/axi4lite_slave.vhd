------------------------------------------------------------------------------
-- Generic AXI4-Lite slave for SCF exam (labo5 EMI handshake + configurable map).
-- Datapath block marked TODO — replace with FIR, convolution, or other IP.
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
        -- TODO: export irq_o => connect in Qsys to hps_0.f2h_irq if required
    );
end entity axi4lite_slave;

architecture rtl of axi4lite_slave is
    constant ADDR_LSB : integer := (AXI_DATA_WIDTH / 32) + 1;

    constant CST_CONSTANT : std_logic_vector(31 downto 0) := x"BADB100D";
    constant CST_BAD_ADDR : std_logic_vector(31 downto 0) := x"BADCAB1E";

    signal reset_s          : std_logic;
    signal axi_awready_s    : std_logic;
    signal axi_wready_s     : std_logic;
    signal axi_bresp_s      : std_logic_vector(1 downto 0);
    signal axi_waddr_done_s : std_logic;
    signal axi_bvalid_s     : std_logic;
    signal axi_arready_s    : std_logic;
    signal axi_rresp_s      : std_logic_vector(1 downto 0);
    signal axi_raddr_done_s : std_logic;
    signal axi_rvalid_s     : std_logic;
    signal axi_waddr_mem_s  : std_logic_vector(AXI_ADDR_WIDTH - 1 downto ADDR_LSB);
    signal axi_data_wren_s  : std_logic;
    signal axi_write_done_s : std_logic;
    signal axi_araddr_mem_s : std_logic_vector(AXI_ADDR_WIDTH - 1 downto ADDR_LSB);
    signal axi_data_rden_s  : std_logic;
    signal axi_read_done_s  : std_logic;
    signal axi_rdata_s      : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

    signal test_s           : std_logic_vector(31 downto 0);
    signal param_0_s        : std_logic_vector(31 downto 0);
    signal param_1_s        : std_logic_vector(31 downto 0);
    signal param_2_s        : std_logic_vector(31 downto 0);
    signal data_in_s        : std_logic_vector(31 downto 0);
    signal data_out_s       : std_logic_vector(31 downto 0);
    signal cmd_reset_s      : std_logic;

    signal st_busy_s        : std_logic;
    signal st_done_s        : std_logic;
    signal st_out_ready_s   : std_logic;

begin
    reset_s <= reset_i;

    st_busy_s      <= '0';
    st_done_s      <= st_out_ready_s;
    st_out_ready_s <= '1' when unsigned(data_out_s) /= 0 or unsigned(data_in_s) /= 0 else '0';

    -- === AXI write address (labo5) ===
    process (reset_s, clk_i)
    begin
        if reset_s = '1' then
            axi_awready_s <= '0'; axi_waddr_done_s <= '0'; axi_waddr_mem_s <= (others => '0');
        elsif rising_edge(clk_i) then
            axi_waddr_done_s <= '0';
            if axi_awready_s = '1' and axi_awvalid_i = '1' then
                axi_awready_s <= '0'; axi_waddr_done_s <= '1';
                axi_waddr_mem_s <= axi_awaddr_i(AXI_ADDR_WIDTH - 1 downto ADDR_LSB);
            elsif axi_write_done_s = '1' then
                axi_awready_s <= '1';
            end if;
        end if;
    end process;
    axi_awready_o <= axi_awready_s;

    process (reset_s, clk_i)
    begin
        if reset_s = '1' then axi_wready_s <= '0';
        elsif rising_edge(clk_i) then
            if axi_wready_s = '1' and axi_wvalid_i = '1' then axi_wready_s <= '0';
            elsif axi_waddr_done_s = '1' then axi_wready_s <= '1';
            end if;
        end if;
    end process;
    axi_wready_o <= axi_wready_s;
    axi_data_wren_s <= axi_wready_s and axi_wvalid_i;

    process (reset_s, clk_i)
        variable idx : natural;
    begin
        if reset_s = '1' or cmd_reset_s = '1' then
            test_s <= (others => '0'); param_0_s <= (others => '0');
            param_1_s <= (others => '0'); param_2_s <= (others => '0');
            data_in_s <= (others => '0'); data_out_s <= (others => '0');
            axi_write_done_s <= '1'; cmd_reset_s <= '0';
        elsif rising_edge(clk_i) then
            axi_write_done_s <= '0';
            if axi_data_wren_s = '1' then
                axi_write_done_s <= '1';
                idx := to_integer(unsigned(axi_waddr_mem_s));
                case idx is
                    when 1 => test_s <= axi_wdata_i;
                    when 2 => if axi_wstrb_i(3) = '1' then cmd_reset_s <= axi_wdata_i(31); end if;
                    when 3 => param_0_s <= axi_wdata_i;
                    when 4 => param_1_s <= axi_wdata_i;
                    when 5 => param_2_s <= axi_wdata_i;
                    when 6 =>
                        data_in_s <= axi_wdata_i;
                        -- TODO: replace stub with FIR / convolution / filter datapath
                        -- Stub: y = p0*x + p1 (demo only — not a real filter)
                        data_out_s <= std_logic_vector(
                            unsigned(axi_wdata_i(7 downto 0)) * unsigned(param_0_s(7 downto 0))
                            + unsigned(param_1_s(7 downto 0)));
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    process (reset_s, clk_i)
    begin
        if reset_s = '1' then axi_bvalid_s <= '0'; axi_bresp_s <= "00";
        elsif rising_edge(clk_i) then
            if axi_data_wren_s = '1' then axi_bvalid_s <= '1'; axi_bresp_s <= "00";
            elsif axi_bready_i = '1' then axi_bvalid_s <= '0';
            end if;
        end if;
    end process;
    axi_bvalid_o <= axi_bvalid_s; axi_bresp_o <= axi_bresp_s;

    process (reset_s, clk_i)
    begin
        if reset_s = '1' then
            axi_arready_s <= '1'; axi_raddr_done_s <= '0'; axi_araddr_mem_s <= (others => '1');
        elsif rising_edge(clk_i) then
            if axi_arready_s = '1' and axi_arvalid_i = '1' then
                axi_arready_s <= '0'; axi_raddr_done_s <= '1';
                axi_araddr_mem_s <= axi_araddr_i(AXI_ADDR_WIDTH - 1 downto ADDR_LSB);
            elsif axi_raddr_done_s = '1' and axi_rvalid_s = '0' then
                axi_raddr_done_s <= '0';
            elsif axi_read_done_s = '1' then axi_arready_s <= '1';
            end if;
        end if;
    end process;
    axi_arready_o <= axi_arready_s;

    process (reset_s, clk_i)
    begin
        if reset_s = '1' then axi_rvalid_s <= '0'; axi_read_done_s <= '0'; axi_rresp_s <= "00";
        elsif rising_edge(clk_i) then
            axi_read_done_s <= '0';
            if axi_raddr_done_s = '1' and axi_rvalid_s = '0' then
                axi_rvalid_s <= '1'; axi_rresp_s <= "00";
            elsif axi_rvalid_s = '1' and axi_rready_i = '1' then
                axi_rvalid_s <= '0'; axi_read_done_s <= '1';
            end if;
        end if;
    end process;
    axi_rvalid_o <= axi_rvalid_s; axi_rresp_o <= axi_rresp_s;
    axi_data_rden_s <= axi_raddr_done_s and (not axi_rvalid_s);

    process (all)
        variable idx : natural;
    begin
        idx := to_integer(unsigned(axi_araddr_mem_s));
        axi_rdata_s <= CST_BAD_ADDR;
        if idx <= 15 then
            case idx is
                when 0 => axi_rdata_s <= CST_CONSTANT;
                when 1 => axi_rdata_s <= test_s;
                when 2 =>
                    axi_rdata_s(0) <= st_busy_s;
                    axi_rdata_s(1) <= st_done_s;
                    axi_rdata_s(2) <= st_out_ready_s;
                    axi_rdata_s(31 downto 3) <= (others => '0');
                when 3 => axi_rdata_s <= param_0_s;
                when 4 => axi_rdata_s <= param_1_s;
                when 5 => axi_rdata_s <= param_2_s;
                when 7 => axi_rdata_s <= data_out_s;
                when others => axi_rdata_s <= CST_BAD_ADDR;
            end case;
        end if;
    end process;

    process (reset_s, clk_i)
    begin
        if reset_s = '1' then axi_rdata_o <= (others => '0');
        elsif rising_edge(clk_i) then
            if axi_data_rden_s = '1' then axi_rdata_o <= axi_rdata_s; end if;
        end if;
    end process;

end architecture rtl;
