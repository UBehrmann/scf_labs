-- synthesis VHDL_INPUT_VERSION VHDL_2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.conv_engine_pkg.all;

entity conv_engine is
    generic (
        KERN_W : integer := 3;
        KERN_H : integer := 3
    );
    port (
        clk_i     : in  std_logic;
        rst_i     : in  std_logic;
        compute_i : in  std_logic;
        valid_o   : out std_logic;
        inputs_i  : in  input_array_t(0 to KERN_H - 1, 0 to KERN_W - 1);
        kernel_i  : in  kernel_array_t(0 to KERN_H - 1, 0 to KERN_W - 1);
        result_o  : out signed(DATASIZE_OUT - 1 downto 0)
    );
end entity conv_engine;

architecture rtl of conv_engine is
begin
    process (all)
        variable acc : integer;
    begin
        valid_o  <= '0';
        result_o <= (others => '0');
        if rst_i = '0' and compute_i = '1' then
            acc := 0;
            for row in 0 to KERN_H - 1 loop
                for col in 0 to KERN_W - 1 loop
                    acc := acc + to_integer(inputs_i(row, col)) * kernel_i(row, col);
                end loop;
            end loop;
            result_o <= to_signed(acc, DATASIZE_OUT);
            valid_o  <= '1';
        end if;
    end process;
end architecture rtl;
