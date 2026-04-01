-- =============================================================================
-- MEALY FIFO
--
-- In a Mealy machine the outputs are combinatorial functions of BOTH the
-- current state AND the current inputs.
--
-- Differences from fifo.vhd (Moore):
--
--   full_o / empty_o  (MEALY_FLAGS process):
--     Moore  : full_o  = f(counter_s)          <- state only
--     Mealy  : full_o  = f(counter_s, op_s)    <- state + input
--     The flag anticipates the effect of the operation happening RIGHT NOW,
--     not just after the next clock edge.
--     Example: if counter_s = FIFOSIZE and rd_i = '1', full_o goes low
--     immediately this cycle instead of waiting for the next edge.
--
--   rd_data_o  (MEALY_DATA process):
--     Moore  : always shows memory[rptr]        <- one-cycle latency after read
--     Mealy  : when rd_i = '1', immediately shows memory[rptr+1] (look-ahead)
--     This is called a "show-ahead" or "fall-through" FIFO.
--     Note: this violates the spec ("output changes at next clock after rd_i"),
--     it is included here purely to illustrate the Mealy output dependency.
--
-- The SYNC and MEMORY processes are identical to the Moore version: the
-- state transition logic does not change — only the output logic changes.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY fifo_mealy IS
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
END fifo_mealy;

ARCHITECTURE mealy OF fifo_mealy IS

	TYPE memory_type IS ARRAY(0 TO FIFOSIZE - 1) OF STD_LOGIC_VECTOR(DATASIZE - 1 DOWNTO 0);
	TYPE op_type     IS (OP_NONE, OP_READ, OP_WRITE, OP_BOTH);

	SIGNAL memory_s  : memory_type;
	SIGNAL rptr_s    : INTEGER RANGE 0 TO FIFOSIZE - 1 := 0;
	SIGNAL wptr_s    : INTEGER RANGE 0 TO FIFOSIZE - 1 := 0;
	SIGNAL counter_s : INTEGER RANGE 0 TO FIFOSIZE     := 0;
	SIGNAL full_s    : STD_LOGIC;
	SIGNAL empty_s   : STD_LOGIC;
	SIGNAL op_s      : op_type;

BEGIN

	op_s <= OP_BOTH  WHEN wr_i = '1' AND rd_i = '1' ELSE
	        OP_WRITE WHEN wr_i = '1'                 ELSE
	        OP_READ  WHEN rd_i = '1'                 ELSE
	        OP_NONE;

	-- Internal Moore-style flags used by the SYNC process
	full_s  <= '1' WHEN counter_s = FIFOSIZE ELSE '0';
	empty_s <= '1' WHEN counter_s = 0        ELSE '0';

	-- -------------------------------------------------------------------------
	-- MEALY output: full_o and empty_o anticipate the effect of the current op
	-- -------------------------------------------------------------------------
	MEALY_FLAGS : PROCESS (counter_s, op_s) BEGIN
		-- Start from the Moore (state-only) defaults
		IF counter_s = FIFOSIZE THEN full_o  <= '1'; ELSE full_o  <= '0'; END IF;
		IF counter_s = 0        THEN empty_o <= '1'; ELSE empty_o <= '0'; END IF;

		CASE op_s IS

			WHEN OP_READ =>
				-- A read will decrement counter; anticipate the new state now
				IF counter_s = FIFOSIZE THEN full_o  <= '0'; END IF;  -- leaves full
				IF counter_s = 1        THEN empty_o <= '1'; END IF;  -- becomes empty

			WHEN OP_WRITE =>
				-- A write will increment counter; anticipate the new state now
				IF counter_s = FIFOSIZE - 1 THEN full_o  <= '1'; END IF;  -- becomes full
				IF counter_s = 0            THEN empty_o <= '0'; END IF;  -- leaves empty

			WHEN OP_BOTH =>
				-- Full + simultaneous rd: only read happens (write blocked) -> leaves full
				IF counter_s = FIFOSIZE THEN full_o  <= '0'; END IF;
				-- Empty + simultaneous wr: only write happens (read blocked) -> leaves empty
				IF counter_s = 0        THEN empty_o <= '0'; END IF;
				-- Neither full nor empty: both happen, net zero -> no flag change

			WHEN OTHERS => NULL;

		END CASE;
	END PROCESS MEALY_FLAGS;

	-- -------------------------------------------------------------------------
	-- MEALY output: rd_data_o look-ahead
	-- When rd_i is asserted and the FIFO is not empty, immediately present the
	-- word that will be at rptr AFTER this read (rptr + 1), so the consumer
	-- sees the new data in the same cycle as it asserts rd_i.
	-- -------------------------------------------------------------------------
	MEALY_DATA : PROCESS (rptr_s, memory_s, op_s, empty_s) BEGIN
		IF op_s = OP_READ AND empty_s = '0' THEN
			data_o <= memory_s((rptr_s + 1) MOD FIFOSIZE);
		ELSE
			data_o <= memory_s(rptr_s);
		END IF;
	END PROCESS MEALY_DATA;

	-- -------------------------------------------------------------------------
	-- State transition: identical to the Moore version
	-- -------------------------------------------------------------------------
	SYNC : PROCESS (clk_i, rst_i) BEGIN
		IF rst_i = '1' THEN
			rptr_s    <= 0;
			wptr_s    <= 0;
			counter_s <= 0;
		ELSIF RISING_EDGE(clk_i) THEN
			CASE op_s IS

				WHEN OP_WRITE =>
					IF full_s = '0' THEN
						wptr_s    <= (wptr_s + 1) MOD FIFOSIZE;
						counter_s <= counter_s + 1;
					END IF;

				WHEN OP_READ =>
					IF empty_s = '0' THEN
						rptr_s    <= (rptr_s + 1) MOD FIFOSIZE;
						counter_s <= counter_s - 1;
					END IF;

				WHEN OP_BOTH =>
					IF full_s = '0' AND empty_s = '0' THEN
						wptr_s <= (wptr_s + 1) MOD FIFOSIZE;
						rptr_s <= (rptr_s + 1) MOD FIFOSIZE;
					ELSIF full_s = '0' THEN
						wptr_s    <= (wptr_s + 1) MOD FIFOSIZE;
						counter_s <= counter_s + 1;
					ELSIF empty_s = '0' THEN
						rptr_s    <= (rptr_s + 1) MOD FIFOSIZE;
						counter_s <= counter_s - 1;
					END IF;

				WHEN OTHERS => NULL;

			END CASE;
		END IF;
	END PROCESS SYNC;

	MEMORY : PROCESS (clk_i) BEGIN
		IF RISING_EDGE(clk_i) THEN
			IF (op_s = OP_WRITE OR op_s = OP_BOTH) AND full_s = '0' THEN
				memory_s(wptr_s) <= data_i;
			END IF;
		END IF;
	END PROCESS MEMORY;

END mealy;
