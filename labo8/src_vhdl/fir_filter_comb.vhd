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
  type sample_array_t is array (natural range <>) of signed(DATASIZE-1 downto 0);
  constant ACC_W : positive := DATASIZE + COEFFSIZE + 8;

  signal samples_r    : sample_array_t(0 to ORDER);

begin
  din_ready_o <= '1';

  p_shift_reg : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      samples_r <= (others => (others => '0'));
    elsif rising_edge(clk_i) then
      for k in ORDER downto 1 loop
        samples_r(k) <= samples_r(k-1);
      end loop;

      if din_valid_i = '1' then
        samples_r(0) <= signed(din_i);
      else
        samples_r(0) <= (others => '0');
      end if;
    end if;
  end process;

  p_mac_comb : process(samples_r, coeffs_i)
    variable acc_v : signed(ACC_W-1 downto 0);
  begin
    acc_v := (others => '0');
    for k in 0 to ORDER loop
      acc_v := acc_v + resize(samples_r(k) * coeffs_i(k), ACC_W);
    end loop;
    dout_o <= std_logic_vector(resize(shift_right(acc_v, COMMAPOS), DATASIZE));
  end process;
  dout_valid_o <= '1';

end architecture combi;
