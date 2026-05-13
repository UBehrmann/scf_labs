--==============================================================================
--  File        : fir_filter_comb.vhd
--  Description : Finite Impulse Response (FIR) Filter - Combinational version
--
--  Author      : REDS institute
--  Date        : 2026
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fir_filter_pkg.all;

entity fir_filter is
  generic (
    ORDER       : positive := 8;    -- Filter order
    DATASIZE    : positive := 16;   -- Input/output data width
    COEFFSIZE   : positive := 16;   -- Coefficient width
    COMMAPOS    : natural := 0      -- Position of comma for computations
  );
  port (
    clk_i        : in  std_logic;
    rst_i        : in  std_logic;
    din_valid_i  : in  std_logic;
    din_i        : in  std_logic_vector(DATASIZE-1 downto 0);
    din_ready_o  : out std_logic;
    coeffs_i     : in  coeff_array(0 to ORDER);
    dout_valid_o : out std_logic;
    dout_o       : out std_logic_vector(DATASIZE-1 downto 0);
    dout_ready_i : in  std_logic
  );
end entity fir_filter;

architecture combi of fir_filter is
  ----------------------------------------------------------------------------
  -- Registre des entrees
  ----------------------------------------------------------------------------
  type data_array_t is array (0 to ORDER) of signed(DATASIZE-1 downto 0);
  signal x_reg : data_array_t;
  
  ----------------------------------------------------------------------------
  -- Constantes
  ----------------------------------------------------------------------------
  constant ACC_W : positive := DATASIZE + COEFFSIZE + 8;
begin
  din_ready_o <= '1';

  ----------------------------------------------------------------------------
  -- REGISTRES / DATAPATH
  ----------------------------------------------------------------------------
  process(clk_i, rst_i)
  begin
    if rst_i = '1' then
        x_reg <= (others => (others => '0'));
    elsif rising_edge(clk_i) then  
        -- Shift register (entrée FIR)
        if din_valid_i = '1' then
          -- x_reg(0) est mis à jour au front d’horloge,
          -- donc x_reg(1) lit encore l’ancienne valeur de x_reg(0)
          x_reg(0) <= signed(din_i);

          for i in 1 to ORDER loop
            x_reg(i) <= x_reg(i-1);
          end loop;
        end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- COMBINATOIRE
  ----------------------------------------------------------------------------
  process(x_reg, coeffs_i)
    variable acc_v : signed(ACC_W-1 downto 0);
  begin
    acc_v := (others => '0');
    for k in 0 to ORDER loop
      acc_v := acc_v + resize(x_reg(k) * coeffs_i(k), ACC_W);
    end loop;
    dout_o <= std_logic_vector(resize(shift_right(acc_v, COMMAPOS), DATASIZE));
  end process;
  
  
  dout_valid_o <= '1';

end architecture combi;
