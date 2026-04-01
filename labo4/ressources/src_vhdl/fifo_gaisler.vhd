------------------------------------------------------------------------------------------
-- HEIG-VD
-- Haute Ecole d'Ingenerie et de Gestion du Canton de Vaud
-- School of Business and Engineering in Canton de Vaud
------------------------------------------------------------------------------------------
-- REDS Institute
-- Reconfigurable Embedded Digital Systems
------------------------------------------------------------------------------------------
--
-- File                 : fifo_gaisler.vhd
-- Author               : Urs Behrmann
-- Date                 : 31.03.2026
--
-- Context              : HPA
--
------------------------------------------------------------------------------------------
-- Description : FIFO module - Gaisler (two-process) coding style
--
------------------------------------------------------------------------------------------
-- Dependencies :
--
------------------------------------------------------------------------------------------
-- Modifications :
-- Ver    Date        Engineer      Comments
-- 0.0    31.03.2026  UBN         Initial version (Gaisler style).
--
------------------------------------------------------------------------------------------


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY fifo_gaisler IS
	GENERIC (
		FIFOSIZE : INTEGER := 8;
		DATASIZE : INTEGER := 8
	);
	PORT (
		clk_i     : IN  STD_LOGIC;
		rst_i     : IN  STD_LOGIC;
		wr_i      : IN  STD_LOGIC;
		rd_i      : IN  STD_LOGIC;
		wr_data_i : IN  STD_LOGIC_VECTOR(DATASIZE - 1 DOWNTO 0);
		rd_data_o : OUT STD_LOGIC_VECTOR(DATASIZE - 1 DOWNTO 0);
		full_o    : OUT STD_LOGIC;
		empty_o   : OUT STD_LOGIC
	);
END fifo_gaisler;

ARCHITECTURE behave OF fifo_gaisler IS

	TYPE memory_type IS ARRAY(0 TO FIFOSIZE - 1) OF STD_LOGIC_VECTOR(DATASIZE - 1 DOWNTO 0);

	-- Encodes all four combinations of rd_i / wr_i
	TYPE op_type IS (OP_NONE, OP_READ, OP_WRITE, OP_BOTH);

	-- All state registers are bundled in a single record (Gaisler style)
	TYPE reg_type IS RECORD
		rptr    : INTEGER RANGE 0 TO FIFOSIZE - 1;
		wptr    : INTEGER RANGE 0 TO FIFOSIZE - 1;
		counter : INTEGER RANGE 0 TO FIFOSIZE;
		memory  : memory_type;
	END RECORD;

	CONSTANT RES_REG : reg_type := (
		rptr    => 0,
		wptr    => 0,
		counter => 0,
		memory  => (OTHERS => (OTHERS => '0'))
	);

	-- r  : current registered state
	-- rin: next state (combinational)
	SIGNAL r, rin : reg_type := RES_REG;

BEGIN

	-- -------------------------------------------------------------------------
	-- Combinational process: computes next state and drives all outputs
	-- -------------------------------------------------------------------------
	COMB : PROCESS (r, wr_i, rd_i, wr_data_i)
		VARIABLE v       : reg_type;
		VARIABLE full_v  : STD_LOGIC;
		VARIABLE empty_v : STD_LOGIC;
		VARIABLE op_v    : op_type;
	BEGIN
		v := r; -- default: hold current state

		-- Decode the requested operation from control inputs
		IF    wr_i = '1' AND rd_i = '1' THEN op_v := OP_BOTH;
		ELSIF wr_i = '1'                THEN op_v := OP_WRITE;
		ELSIF rd_i = '1'                THEN op_v := OP_READ;
		ELSE                                 op_v := OP_NONE;
		END IF;

		-- Status flags derived from current state
		IF r.counter = FIFOSIZE THEN full_v  := '1'; ELSE full_v  := '0'; END IF;
		IF r.counter = 0        THEN empty_v := '1'; ELSE empty_v := '0'; END IF;

		CASE op_v IS

			WHEN OP_WRITE =>
				IF full_v = '0' THEN
					v.memory(r.wptr) := wr_data_i;
					v.wptr           := (r.wptr + 1) MOD FIFOSIZE;
					v.counter        := r.counter + 1;
				END IF;

			WHEN OP_READ =>
				IF empty_v = '0' THEN
					v.rptr    := (r.rptr + 1) MOD FIFOSIZE;
					v.counter := r.counter - 1;
				END IF;

			WHEN OP_BOTH =>
				-- Simultaneous read + write: advance both pointers, counter unchanged
				IF full_v = '0' AND empty_v = '0' THEN
					v.memory(r.wptr) := wr_data_i;
					v.wptr           := (r.wptr + 1) MOD FIFOSIZE;
					v.rptr           := (r.rptr + 1) MOD FIFOSIZE;
				-- FIFO is empty: write is accepted, read is ignored
				ELSIF full_v = '0' THEN
					v.memory(r.wptr) := wr_data_i;
					v.wptr           := (r.wptr + 1) MOD FIFOSIZE;
					v.counter        := r.counter + 1;
				-- FIFO is full: read is accepted, write is discarded
				ELSIF empty_v = '0' THEN
					v.rptr    := (r.rptr + 1) MOD FIFOSIZE;
					v.counter := r.counter - 1;
				END IF;

			WHEN OTHERS => NULL;

		END CASE;

		-- Drive outputs
		full_o  <= full_v;
		empty_o <= empty_v;

		-- rd_data_o is valid only when the FIFO is not empty
		IF empty_v = '0' THEN
			rd_data_o <= r.memory(r.rptr);
		ELSE
			rd_data_o <= (OTHERS => '0');
		END IF;

		rin <= v;
	END PROCESS COMB;

	-- -------------------------------------------------------------------------
	-- Sequential process: registers the next state on every rising clock edge
	-- -------------------------------------------------------------------------
	REGS : PROCESS (clk_i, rst_i) BEGIN
		IF rst_i = '1' THEN
			r <= RES_REG;
		ELSIF RISING_EDGE(clk_i) THEN
			r <= rin;
		END IF;
	END PROCESS REGS;

END behave;
