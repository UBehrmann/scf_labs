-- =============================================================================
-- MEDVEDEV FIFO
--
-- A Medvedev machine is a special case of Moore where the outputs ARE the
-- state flip-flop outputs directly, with zero combinatorial logic between
-- the registers and the output pins.
--
-- Differences from fifo.vhd (Moore):
--   Moore    : full_o <= '1' WHEN counter_s = FIFOSIZE ELSE '0'  <- comb. logic
--   Medvedev : full_o <= full_r   where full_r is a plain register <- no logic
--
-- Trade-off: full_r and empty_r are updated on the clock edge alongside the
-- counter, so they carry the same latency as any other state bit.
-- rd_data_o is also registered: the word at rptr is captured on each rising
-- edge, adding one cycle of read latency compared to the Moore version.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY fifo_medvedev IS
	GENERIC (
		FIFOSIZE : INTEGER := 8;
		DATASIZE : INTEGER := 8
	);
	PORT (
		clk_i     : IN  STD_LOGIC;
		rst_i     : IN  STD_LOGIC;
		wr_i      : IN  STD_LOGIC;
		rd_i      : IN  STD_LOGIC;
		data_i    : IN  STD_LOGIC_VECTOR(DATASIZE - 1 DOWNTO 0);
		data_o    : OUT STD_LOGIC_VECTOR(DATASIZE - 1 DOWNTO 0);
		full_o    : OUT STD_LOGIC;
		empty_o   : OUT STD_LOGIC
	);
END fifo_medvedev;

ARCHITECTURE medvedev OF fifo_medvedev IS

	TYPE memory_type IS ARRAY(0 TO FIFOSIZE - 1) OF STD_LOGIC_VECTOR(DATASIZE - 1 DOWNTO 0);
	TYPE op_type     IS (OP_NONE, OP_READ, OP_WRITE, OP_BOTH);

	SIGNAL memory_s  : memory_type;
	SIGNAL rptr_s    : INTEGER RANGE 0 TO FIFOSIZE - 1 := 0;
	SIGNAL wptr_s    : INTEGER RANGE 0 TO FIFOSIZE - 1 := 0;
	SIGNAL counter_s : INTEGER RANGE 0 TO FIFOSIZE     := 0;
	SIGNAL op_s      : op_type;

	-- Medvedev state bits: these registers are the outputs — no logic in between
	SIGNAL full_r    : STD_LOGIC                                    := '0';
	SIGNAL empty_r   : STD_LOGIC                                    := '1';
	SIGNAL rd_data_r : STD_LOGIC_VECTOR(DATASIZE - 1 DOWNTO 0)     := (OTHERS => '0');

BEGIN

	op_s <= OP_BOTH  WHEN wr_i = '1' AND rd_i = '1' ELSE
	        OP_WRITE WHEN wr_i = '1'                 ELSE
	        OP_READ  WHEN rd_i = '1'                 ELSE
	        OP_NONE;

	-- Direct wire: state register -> output pin, no combinatorial block
	full_o  <= full_r;
	empty_o <= empty_r;
	data_o  <= rd_data_r;

	-- Pointer and counter management; full_r/empty_r updated here as state bits
	SYNC : PROCESS (clk_i, rst_i)
		-- Variable lets us compute the next counter value within one process
		-- and immediately derive the next full/empty state from it
		VARIABLE v_counter : INTEGER RANGE 0 TO FIFOSIZE;
	BEGIN
		IF rst_i = '1' THEN
			rptr_s    <= 0;
			wptr_s    <= 0;
			counter_s <= 0;
			full_r    <= '0';
			empty_r   <= '1';
		ELSIF RISING_EDGE(clk_i) THEN
			v_counter := counter_s;

			CASE op_s IS

				WHEN OP_WRITE =>
					IF full_r = '0' THEN
						wptr_s    <= (wptr_s + 1) MOD FIFOSIZE;
						v_counter := v_counter + 1;
					END IF;

				WHEN OP_READ =>
					IF empty_r = '0' THEN
						rptr_s    <= (rptr_s + 1) MOD FIFOSIZE;
						v_counter := v_counter - 1;
					END IF;

				WHEN OP_BOTH =>
					IF full_r = '0' AND empty_r = '0' THEN
						wptr_s <= (wptr_s + 1) MOD FIFOSIZE;
						rptr_s <= (rptr_s + 1) MOD FIFOSIZE;
					ELSIF full_r = '0' THEN
						wptr_s    <= (wptr_s + 1) MOD FIFOSIZE;
						v_counter := v_counter + 1;
					ELSIF empty_r = '0' THEN
						rptr_s    <= (rptr_s + 1) MOD FIFOSIZE;
						v_counter := v_counter - 1;
					END IF;

				WHEN OTHERS => NULL;

			END CASE;

			counter_s <= v_counter;

			-- Update Medvedev output state bits from the computed next counter
			IF v_counter = FIFOSIZE THEN full_r  <= '1'; ELSE full_r  <= '0'; END IF;
			IF v_counter = 0        THEN empty_r <= '1'; ELSE empty_r <= '0'; END IF;
		END IF;
	END PROCESS SYNC;

	-- Memory write + registered read output
	MEMORY : PROCESS (clk_i) BEGIN
		IF RISING_EDGE(clk_i) THEN
			IF (op_s = OP_WRITE OR op_s = OP_BOTH) AND full_r = '0' THEN
				memory_s(wptr_s) <= data_i;
			END IF;
			-- rd_data_r is a plain register: captures memory[rptr] every cycle
			-- (one-cycle latency after rptr advances compared to Moore)
			rd_data_r <= memory_s(rptr_s);
		END IF;
	END PROCESS MEMORY;

END medvedev;
