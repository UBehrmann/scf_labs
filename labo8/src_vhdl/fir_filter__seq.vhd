--==============================================================================
--  File        : fir_filter.vhd
--  Description : Finite Impulse Response (FIR) Filter
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

architecture sequential of fir_filter is

  ----------------------------------------------------------------------------
  -- Registre des entrees
  ----------------------------------------------------------------------------
  type data_array_t is array (0 to ORDER) of signed(DATASIZE-1 downto 0);
  signal x_reg : data_array_t;

  ----------------------------------------------------------------------------
  -- Etats
  ----------------------------------------------------------------------------
  type state_t is (IDLE, MAC, LOAD, OUTPUT);
  signal state, next_state : state_t;

  ----------------------------------------------------------------------------
  -- Singaux de controle
  ----------------------------------------------------------------------------
  signal shift_en  : std_logic;
  signal acc_en    : std_logic;
  signal acc_clear : std_logic;
  signal k_inc     : std_logic;
  signal k_clear   : std_logic;
  signal dout_load : std_logic;

  ----------------------------------------------------------------------------
  -- Compteur k
  ----------------------------------------------------------------------------
  signal k_counter : natural range 0 to ORDER;

  ----------------------------------------------------------------------------
  -- Taille large pour éviter overflow
  ----------------------------------------------------------------------------
  signal acc_reg  : signed(DATASIZE + COEFFSIZE + 4 downto 0);
  signal product  : signed(DATASIZE + COEFFSIZE - 1 downto 0);
  signal dout_reg : signed(DATASIZE-1 downto 0);

begin

  ----------------------------------------------------------------------------
  -- Multiplication combinatoire
  ----------------------------------------------------------------------------
  product <= x_reg(k_counter) * coeffs_i(k_counter);

  ----------------------------------------------------------------------------
  -- Sortie
  ----------------------------------------------------------------------------
  dout_o <= std_logic_vector(dout_reg);

  ----------------------------------------------------------------------------
  -- Handshake entrée
  ----------------------------------------------------------------------------
  din_ready_o <= '1' when state = IDLE else '0';

  ----------------------------------------------------------------------------
  -- REGISTRES / DATAPATH
  ----------------------------------------------------------------------------
  process(clk_i, rst_i)
    variable acc_next_v : signed(acc_reg'range);
  begin
    if rst_i = '1' then
      x_reg        <= (others => (others => '0'));
      acc_reg      <= (others => '0');
      dout_reg     <= (others => '0');
      k_counter    <= 0;
      state        <= IDLE;
    elsif rising_edge(clk_i) then
        state <= next_state;

        -- Shift register (entrée FIR)
        if shift_en = '1' then
          -- x_reg(0) est mis à jour au front d’horloge,
          -- donc x_reg(1) lit encore l’ancienne valeur de x_reg(0)
          x_reg(0) <= signed(din_i);

          for i in 1 to ORDER loop
            x_reg(i) <= x_reg(i-1);
          end loop;
        end if;

        -- Accumulateur
        if acc_clear = '1' then
          acc_reg <= (others => '0');

        elsif acc_en = '1' then
          acc_next_v := acc_reg + resize(product, acc_reg'length);
          acc_reg <= acc_next_v;
        end if;

        -- Chargement sortie
        if dout_load = '1' then
          -- Ici on charge acc_reg déjà complet.
          dout_reg <= resize(shift_right(acc_reg, COMMAPOS), DATASIZE);
        end if;

        -- Compteur k
        if k_clear = '1' then
          k_counter <= 0;

        elsif k_inc = '1' then
          if k_counter < ORDER then
            k_counter <= k_counter + 1;
          end if;
        end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- FSM
  ----------------------------------------------------------------------------
  process(state, din_valid_i, dout_ready_i, k_counter)
  begin
    -- valeurs par défaut à chaque cycle
    shift_en     <= '0';
    acc_clear    <= '0';
    acc_en       <= '0';
    k_clear      <= '0';
    k_inc        <= '0';
    dout_load    <= '0';
    dout_valid_o <= '0';
    next_state   <= state;

    case state is

      when IDLE =>
        if din_valid_i = '1' then
          shift_en   <= '1';
          acc_clear  <= '1';
          k_clear    <= '1';
          next_state <= MAC;
        end if;

      when MAC =>
        acc_en <= '1';

        if k_counter = ORDER then
          next_state <= LOAD;
        else
          k_inc <= '1';
        end if;

      when LOAD =>
        dout_load  <= '1';
        next_state <= OUTPUT;

      when OUTPUT =>
        dout_valid_o <= '1';

        if dout_ready_i = '1' then
          next_state <= IDLE;
        end if;

    end case;
  end process;

end architecture sequential;
