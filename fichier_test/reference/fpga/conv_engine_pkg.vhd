library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package conv_engine_pkg is
    constant DATASIZE_IN  : integer := 8;
    constant DATASIZE_KER : integer := 8;
    constant DATASIZE_OUT : integer := 20;

    type input_array_t is array (natural range <>, natural range <>) of
        unsigned(DATASIZE_IN - 1 downto 0);
    type kernel_array_t is array (natural range <>, natural range <>) of
        integer range -2**(DATASIZE_KER - 1) to 2**(DATASIZE_KER - 1) - 1;
end package conv_engine_pkg;
