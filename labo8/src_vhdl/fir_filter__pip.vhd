--==============================================================================
--  File        : fir_filter_pipe.vhd
--  Description : Finite Impulse Response (FIR) Filter - Pipeline version
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
    ORDER       : positive := 8;
    DATASIZE    : positive := 16;
    COEFFSIZE   : positive := 16;
    COMMAPOS    : natural := 0
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

architecture pipeline of fir_filter is
  ----------------------------------------------------------------------------
  -- Constantes
  ----------------------------------------------------------------------------
  constant ACC_W : positive := DATASIZE + COEFFSIZE + 8;

  ----------------------------------------------------------------------------
  -- Registre des entrees
  ----------------------------------------------------------------------------
  type data_array_t is array (0 to ORDER) of signed(DATASIZE-1 downto 0);
  signal x_reg : data_array_t;

  ----------------------------------------------------------------------------
  -- Registre des sorties
  ----------------------------------------------------------------------------
  signal dout_valid_reg : std_logic;
  
  ----------------------------------------------------------------------------
  -- Pipeline d'accumulation
  ----------------------------------------------------------------------------
  type acc_array_t is array (0 to ORDER) of signed(ACC_W-1 downto 0);
  signal acc_pipe : acc_array_t;

  ----------------------------------------------------------------------------
  -- Pipeline des produits
  ----------------------------------------------------------------------------
  type prod_pipe_t is array (0 to ORDER, 0 to ORDER-1) of signed(ACC_W-1 downto 0);
  signal prod_pipe : prod_pipe_t;
  
  ----------------------------------------------------------------------------
  -- Pipeline de validité
  ----------------------------------------------------------------------------
  signal valid_pipe : std_logic_vector(0 to ORDER);

begin
  ----------------------------------------------------------------------------
  -- Handshake entrée
  ----------------------------------------------------------------------------
  din_ready_o <= '1';
  
  ----------------------------------------------------------------------------
  -- Sorties
  ----------------------------------------------------------------------------
  dout_o       <= std_logic_vector(resize(shift_right(acc_pipe(ORDER), COMMAPOS), DATASIZE));
  dout_valid_o <= dout_valid_reg;

  ----------------------------------------------------------------------------
  -- REGISTRES / DATAPATH
  ----------------------------------------------------------------------------
  process(clk_i, rst_i)
    variable product_v : signed(ACC_W-1 downto 0);
    variable acc_next  : acc_array_t;
  begin
    if rst_i = '1' then
      x_reg      		<= (others => (others => '0'));
      acc_pipe   		<= (others => (others => '0'));
      prod_pipe  		<= (others => (others => (others => '0')));
      valid_pipe 		<= (others => '0');
		dout_valid_reg	<= '0';
    elsif rising_edge(clk_i) then
      ------------------------------------------------------------------------
      -- Shift register (entrée FIR)
      ------------------------------------------------------------------------
      -- x_reg    = valeurs enregistrées avant le front
      if din_valid_i = '1' then
        x_reg(0) <= signed(din_i);
        for i in 1 to ORDER loop
          x_reg(i) <= x_reg(i-1);
        end loop;
      end if;
      
      ------------------------------------------------------------------------
      -- Pipeline de validité
      ------------------------------------------------------------------------
      valid_pipe(0) <= din_valid_i;
      for i in 1 to ORDER loop
        valid_pipe(i) <= valid_pipe(i-1);
      end loop;

      ------------------------------------------------------------------------
      -- Pipeline des produits
      ------------------------------------------------------------------------
      for i in 1 to ORDER loop
        product_v := resize(x_reg(i) * coeffs_i(i), ACC_W);
        prod_pipe(i, 0) <= product_v;
        for d in 1 to i-1 loop
          prod_pipe(i, d) <= prod_pipe(i, d-1);
        end loop;
      end loop;

      ------------------------------------------------------------------------
      -- Etage pipeline
      ------------------------------------------------------------------------
      product_v := resize(x_reg(0) * coeffs_i(0), ACC_W);
      acc_next(0) := product_v;
      for i in 1 to ORDER loop
        acc_next(i) := acc_pipe(i-1) + prod_pipe(i, i-1);
      end loop;

      acc_pipe <= acc_next;
		dout_valid_reg <= valid_pipe(ORDER);
    end if;
  end process;

end architecture pipeline;
