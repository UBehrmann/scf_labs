------------------------------------------------------------------------------------------
-- HEIG-VD
-- Haute Ecole d'Ingenerie et de Gestion du Canton de Vaud
-- School of Business and Engineering in Canton de Vaud
------------------------------------------------------------------------------------------
-- REDS Institute
-- Reconfigurable Embedded Digital Systems
------------------------------------------------------------------------------------------
--
-- File                 : fifo.vhd
-- Author               : Urs Behrmann
-- Date                 : 31.03.2026
--
-- Context              : HPA
--
------------------------------------------------------------------------------------------
-- Description : FIFO module
--
------------------------------------------------------------------------------------------
-- Dependencies :
--
------------------------------------------------------------------------------------------
-- Modifications :
-- Ver    Date        Engineer      Comments
-- 0.0    31.03.2026  UBN         Initial version.
--
------------------------------------------------------------------------------------------


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY fifo IS
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
END fifo;

ARCHITECTURE behave OF fifo IS

	TYPE memory_type IS ARRAY(0 TO FIFOSIZE - 1) OF STD_LOGIC_VECTOR(DATASIZE - 1 DOWNTO 0);

	-- Encodes all four combinations of rd_i / wr_i
	TYPE op_type IS (OP_NONE, OP_READ, OP_WRITE, OP_BOTH);

	SIGNAL memory_s  : memory_type;
	SIGNAL rptr_s    : INTEGER RANGE 0 TO FIFOSIZE - 1 := 0;
	SIGNAL wptr_s    : INTEGER RANGE 0 TO FIFOSIZE - 1 := 0;
	SIGNAL counter_s : INTEGER RANGE 0 TO FIFOSIZE     := 0;
	SIGNAL full_s    : STD_LOGIC;
	SIGNAL empty_s   : STD_LOGIC;
	SIGNAL op_s      : op_type;

BEGIN

	-- Decode the requested operation from the control inputs
	op_s <= OP_BOTH  WHEN wr_i = '1' AND rd_i = '1' ELSE
	        OP_WRITE WHEN wr_i = '1'                 ELSE
	        OP_READ  WHEN rd_i = '1'                 ELSE
	        OP_NONE;

	-- Status flags
	full_s  <= '1' WHEN counter_s = FIFOSIZE ELSE '0';
	empty_s <= '1' WHEN counter_s = 0        ELSE '0';
	full_o  <= full_s;
	empty_o <= empty_s;

	-- Read data is always the word at the current read pointer;
	-- it is valid as soon as empty_s = '0'
	rd_data_o <= memory_s(rptr_s) WHEN empty_s = '0' ELSE (OTHERS => '0');

	-- Synchronous management of read/write pointers and fill counter
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
					-- Simultaneous read + write: advance both pointers, counter unchanged
					IF full_s = '0' AND empty_s = '0' THEN
						wptr_s <= (wptr_s + 1) MOD FIFOSIZE;
						rptr_s <= (rptr_s + 1) MOD FIFOSIZE;
					-- FIFO is empty: write is accepted, read is ignored
					ELSIF full_s = '0' THEN
						wptr_s    <= (wptr_s + 1) MOD FIFOSIZE;
						counter_s <= counter_s + 1;
					-- FIFO is full: read is accepted, write is discarded
					ELSIF empty_s = '0' THEN
						rptr_s    <= (rptr_s + 1) MOD FIFOSIZE;
						counter_s <= counter_s - 1;
					END IF;

				WHEN OTHERS => NULL;

			END CASE;
		END IF;
	END PROCESS SYNC;

	-- Synchronous memory write
	MEMORY : PROCESS (clk_i) BEGIN
		IF RISING_EDGE(clk_i) THEN
			IF (op_s = OP_WRITE OR op_s = OP_BOTH) AND full_s = '0' THEN
				memory_s(wptr_s) <= wr_data_i;
			END IF;
		END IF;
	END PROCESS MEMORY;

END behave;
