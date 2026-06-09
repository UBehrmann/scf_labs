------------------------------------------------------------------------------
-- Minimal 3x3 convolution AXI4-Lite slave (no Altera FIFO IP).
-- Register map: reference/soft/axi.h
------------------------------------------------------------------------------
-- synthesis VHDL_INPUT_VERSION VHDL_2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.conv_engine_pkg.all;

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
    constant ADDR_LSB     : integer := (AXI_DATA_WIDTH / 32) + 1;
    constant KERN_W       : integer := 3;
    constant KERN_H       : integer := 3;
    constant MAX_WIDTH    : integer := 64;
    constant OUT_FIFO_DEP : integer := 256;
    constant ALMOST_PCT   : integer := 80;

    constant CST_CONSTANT : std_logic_vector(31 downto 0) := x"D06512ED";
    constant CST_BAD_ADDR : std_logic_vector(31 downto 0) := x"BADCAB1E";

    type kern_cols_t is array (0 to 2) of std_logic_vector(23 downto 0);
    type u8_line_t is array (0 to MAX_WIDTH - 1) of unsigned(7 downto 0);
    type u8_line3_t is array (0 to 2) of u8_line_t;
    type out_fifo_t is array (0 to OUT_FIFO_DEP - 1) of signed(DATASIZE_OUT - 1 downto 0);

    component conv_engine is
        generic (KERN_W, KERN_H : integer);
        port (
            clk_i, rst_i, compute_i : in  std_logic;
            valid_o                 : out std_logic;
            inputs_i                : in  input_array_t(0 to KERN_H - 1, 0 to KERN_W - 1);
            kernel_i                : in  kernel_array_t(0 to KERN_H - 1, 0 to KERN_W - 1);
            result_o                : out signed(DATASIZE_OUT - 1 downto 0)
        );
    end component;

    signal reset_s            : std_logic;
    signal axi_awready_s      : std_logic;
    signal axi_wready_s       : std_logic;
    signal axi_bresp_s        : std_logic_vector(1 downto 0);
    signal axi_waddr_done_s   : std_logic;
    signal axi_bvalid_s       : std_logic;
    signal axi_arready_s      : std_logic;
    signal axi_rresp_s        : std_logic_vector(1 downto 0);
    signal axi_raddr_done_s   : std_logic;
    signal axi_rvalid_s       : std_logic;
    signal axi_waddr_mem_s    : std_logic_vector(AXI_ADDR_WIDTH - 1 downto ADDR_LSB);
    signal axi_data_wren_s    : std_logic;
    signal axi_write_done_s   : std_logic;
    signal axi_araddr_mem_s   : std_logic_vector(AXI_ADDR_WIDTH - 1 downto ADDR_LSB);
    signal axi_data_rden_s    : std_logic;
    signal axi_read_done_s    : std_logic;
    signal axi_rdata_s        : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

    signal test_s             : std_logic_vector(31 downto 0);
    signal kern_col_s         : kern_cols_t := (others => (others => '0'));
    signal input_width_s      : std_logic_vector(31 downto 0);
    signal rst_command_s      : std_logic;

    signal lines_s            : u8_line3_t := (others => (others => (others => '0')));
    signal wr_col_s           : integer range 0 to MAX_WIDTH - 1 := 0;
    signal wr_row_s           : integer range 0 to 2 := 0;

    signal out_fifo_s         : out_fifo_t := (others => (others => '0'));
    signal out_head_s         : integer range 0 to OUT_FIFO_DEP - 1 := 0;
    signal out_tail_s         : integer range 0 to OUT_FIFO_DEP - 1 := 0;
    signal out_count_s        : integer range 0 to OUT_FIFO_DEP := 0;

    signal conv_inputs_s      : input_array_t(0 to KERN_H - 1, 0 to KERN_W - 1);
    signal conv_kernel_s      : kernel_array_t(0 to KERN_H - 1, 0 to KERN_W - 1);
    signal conv_result_s      : signed(DATASIZE_OUT - 1 downto 0);
    signal conv_valid_s       : std_logic;

    signal in_word_s          : std_logic_vector(31 downto 0);
    signal in_word_valid_s    : std_logic;

    signal output_empty_s     : std_logic;
    signal output_full_s      : std_logic;
    signal output_alm_full_s  : std_logic;
    signal output_alm_empty_s : std_logic;
    signal running_s          : std_logic;
    signal done_s             : std_logic;

begin
    reset_s <= reset_i;

    u_conv : conv_engine
        generic map(KERN_W => KERN_W, KERN_H => KERN_H)
        port map(
            clk_i => clk_i, rst_i => reset_s, compute_i => '1',
            valid_o => conv_valid_s, inputs_i => conv_inputs_s,
            kernel_i => conv_kernel_s, result_o => conv_result_s
        );

    conv_kernel_s <= (
        0 => (0 => to_integer(signed(kern_col_s(0)(7 downto 0))),
              1 => to_integer(signed(kern_col_s(0)(15 downto 8))),
              2 => to_integer(signed(kern_col_s(0)(23 downto 16)))),
        1 => (0 => to_integer(signed(kern_col_s(1)(7 downto 0))),
              1 => to_integer(signed(kern_col_s(1)(15 downto 8))),
              2 => to_integer(signed(kern_col_s(1)(23 downto 16)))),
        2 => (0 => to_integer(signed(kern_col_s(2)(7 downto 0))),
              1 => to_integer(signed(kern_col_s(2)(15 downto 8))),
              2 => to_integer(signed(kern_col_s(2)(23 downto 16))))
    );

    output_empty_s     <= '1' when out_count_s = 0 else '0';
    output_full_s      <= '1' when out_count_s = OUT_FIFO_DEP else '0';
    output_alm_full_s  <= '1' when out_count_s > OUT_FIFO_DEP * ALMOST_PCT / 100 else '0';
    output_alm_empty_s <= '1' when out_count_s < OUT_FIFO_DEP * (100 - ALMOST_PCT) / 100 else '0';
    running_s          <= '1' when in_word_valid_s = '1' else '0';
    done_s             <= '1' when in_word_valid_s = '0' and output_empty_s = '1' else '0';

    -- Write address / data (labo5 EMI)
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
        variable int_waddr_v : natural;
        variable w_data_v    : std_logic_vector(31 downto 0);
    begin
        if reset_s = '1' then
            test_s <= (others => '0'); kern_col_s <= (others => (others => '0'));
            input_width_s <= (others => '0'); axi_write_done_s <= '1';
            in_word_valid_s <= '0'; rst_command_s <= '0';
        elsif rising_edge(clk_i) then
            rst_command_s <= '0'; axi_write_done_s <= '0'; in_word_valid_s <= '0';
            if axi_data_wren_s = '1' then
                axi_write_done_s <= '1';
                int_waddr_v := to_integer(unsigned(axi_waddr_mem_s));
                case int_waddr_v is
                    when 1 => test_s <= axi_wdata_i;
                    when 2 => if axi_wstrb_i(3) = '1' then rst_command_s <= axi_wdata_i(31); end if;
                    when 3 => kern_col_s(0) <= axi_wdata_i(23 downto 0);
                    when 4 => kern_col_s(1) <= axi_wdata_i(23 downto 0);
                    when 5 => kern_col_s(2) <= axi_wdata_i(23 downto 0);
                    when 7 =>
                        w_data_v := axi_wdata_i;
                        if unsigned(w_data_v) <= MAX_WIDTH and unsigned(w_data_v) > 0 then
                            input_width_s <= w_data_v;
                        end if;
                    when 8 => in_word_s <= axi_wdata_i; in_word_valid_s <= '1';
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    process (reset_s, clk_i)
        variable width_i : integer;
        variable c, r    : integer;
        variable px      : unsigned(7 downto 0);
        variable di, dj  : integer;
        variable rr, cc  : integer;
        variable head_v  : integer;
    begin
        if reset_s = '1' or rst_command_s = '1' then
            lines_s <= (others => (others => (others => '0')));
            wr_col_s <= 0; wr_row_s <= 0;
            out_head_s <= 0; out_tail_s <= 0; out_count_s <= 0;
        elsif rising_edge(clk_i) and in_word_valid_s = '1' and unsigned(input_width_s) > 0 then
            width_i := to_integer(unsigned(input_width_s));
            c := wr_col_s; r := wr_row_s;
            for byte_i in 0 to 3 loop
                px := unsigned(in_word_s(8 * byte_i + 7 downto 8 * byte_i));
                lines_s(r)(c) := px;
                if r >= 2 and c >= 2 then
                    for di in 0 to 2 loop
                        for dj in 0 to 2 loop
                            rr := r - 2 + di; cc := c - 2 + dj;
                            conv_inputs_s(di, dj) <= lines_s(rr)(cc);
                        end loop;
                    end loop;
                    if conv_valid_s = '1' and out_count_s < OUT_FIFO_DEP then
                        head_v := out_head_s;
                        out_fifo_s(head_v) <= conv_result_s;
                        if head_v = OUT_FIFO_DEP - 1 then out_head_s <= 0; else out_head_s <= head_v + 1; end if;
                        out_count_s <= out_count_s + 1;
                    end if;
                end if;
                if c = width_i - 1 then c := 0; r := (r + 1) mod 3;
                else c := c + 1; end if;
            end loop;
            wr_col_s <= c; wr_row_s <= r;
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
        variable int_raddr_v : natural;
        variable tail_v      : integer;
    begin
        int_raddr_v := to_integer(unsigned(axi_araddr_mem_s));
        axi_rdata_s <= CST_BAD_ADDR;
        if int_raddr_v <= 15 then
            case int_raddr_v is
                when 0 => axi_rdata_s <= CST_CONSTANT;
                when 1 => axi_rdata_s <= test_s;
                when 2 =>
                    axi_rdata_s(0) <= running_s; axi_rdata_s(1) <= done_s;
                    axi_rdata_s(2) <= output_alm_empty_s; axi_rdata_s(3) <= output_empty_s;
                    axi_rdata_s(4) <= output_alm_full_s; axi_rdata_s(5) <= output_full_s;
                    axi_rdata_s(31 downto 6) <= (others => '0');
                when 3 => axi_rdata_s(23 downto 0) <= kern_col_s(0);
                when 4 => axi_rdata_s(23 downto 0) <= kern_col_s(1);
                when 5 => axi_rdata_s(23 downto 0) <= kern_col_s(2);
                when 6 => axi_rdata_s <= std_logic_vector(to_unsigned(MAX_WIDTH, 32));
                when 7 => axi_rdata_s <= input_width_s;
                when 9 =>
                    if out_count_s > 0 then
                        tail_v := out_tail_s;
                        axi_rdata_s <= std_logic_vector(resize(out_fifo_s(tail_v), 32));
                    else axi_rdata_s <= (others => '0');
                    end if;
                when others => axi_rdata_s <= CST_BAD_ADDR;
            end case;
        end if;
    end process;

    process (reset_s, clk_i)
        variable tail_v : integer;
    begin
        if reset_s = '1' then axi_rdata_o <= (others => '0');
        elsif rising_edge(clk_i) then
            if axi_data_rden_s = '1' then
                axi_rdata_o <= axi_rdata_s;
                if to_integer(unsigned(axi_araddr_mem_s)) = 9 and out_count_s > 0 then
                    tail_v := out_tail_s;
                    if tail_v = OUT_FIFO_DEP - 1 then out_tail_s <= 0; else out_tail_s <= tail_v + 1; end if;
                    out_count_s <= out_count_s - 1;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
