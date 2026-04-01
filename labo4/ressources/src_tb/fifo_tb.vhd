-------------------------------------------------------------------------------
-- HEIG-VD, Haute Ecole d'Ingenierie et de Gestion du canton de Vaud
-- Institut REDS, Reconfigurable & Embedded Digital Systems
--
-- Fichier      : fifo_tb.vhd
--
-- Description  : Testbench for a simple FIFO.  The generic parameter TESTCASE
--                selects the scenario to run:
--                  0       => random/stress test
--                  1       => interleaved wr/rd, discontinuous write
--                  2       => interleaved wr/rd, continuous read
--                  3       => writes and reads both with gaps
--                  4       => 3 writes + pause + 5 writes (fills FIFO), then drain
--                  5       => 2 writes then long pause (read-past-empty)
--                  6       => 5 consecutive writes, then read with one gap
--                  7 / 8   => overlapping wr/rd with a mid-burst gap
--                  9       => 6 writes / read with one gap
--                  10      => 6 writes / continuous drain
--                  11      => fill FIFO completely, then drain
--                  12      => fill FIFO completely, drain one cycle earlier
--                  13      => 3 writes then long pause, late continuous drain
--
-- Auteur       : Yann Thoma, Rick Wertenbroek
-- Date         : 12.03.2015
-- Version      : 3.1
--
--| Modifications |------------------------------------------------------------
-- Version   Auteur      Date               Description
-- 1.0       YTA         see header         First version.
-- 2.0       RWE         15.03.17           TLMVM Version.
-- 3.0       YTA         15.03.21           Adding testcases.
-- 3.1       ---         31.03.26           Refactored: helper procedures to
--                                          eliminate code duplication, case
--                                          statements instead of if-chains,
--                                          error counter, improved end-of-
--                                          simulation report.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tlmvm;
context tlmvm.tlmvm_context;

use work.RNG.all;

------------
-- Entity --
------------
entity fifo_tb is
    generic (
        FIFOSIZE  : integer := 8;
        DATAWIDTH : integer := 8;
        TESTCASE  : integer := 0);
end fifo_tb;

------------------
-- Architecture --
------------------
architecture test_bench of fifo_tb is

    -- TLM channel element type = one FIFO word
    package my_tlm_pkg is new tlm_unbounded_fifo_pkg
        generic map(element_type => std_logic_vector(DATAWIDTH - 1 downto 0));

    ---------------
    -- Constants --
    ---------------
    constant CLK_PERIOD             : time    := 10 ns;
    constant NUMBER_OF_TRANSACTIONS : integer := 100;

    ----------------------
    -- Shared Variables --
    ----------------------
    shared variable fifo_sti      : my_tlm_pkg.tlm_fifo_type; -- Stimuli transactions
    shared variable fifo_obs      : my_tlm_pkg.tlm_fifo_type; -- Observed responses
    shared variable fifo_ref      : my_tlm_pkg.tlm_fifo_type; -- Reference responses
    shared variable error_count_v : integer := 0;

    -------------
    -- Signals --
    -------------
    signal clk_sti      : std_logic;
    signal rst_sti      : std_logic;
    signal full_obs     : std_logic;
    signal empty_obs    : std_logic;
    signal wr_sti       : std_logic;
    signal rd_sti       : std_logic;
    signal data_in_sti  : std_logic_vector(DATAWIDTH - 1 downto 0);
    signal data_out_obs : std_logic_vector(DATAWIDTH - 1 downto 0);

    ----------------
    -- Components --
    ----------------
    component fifo
        generic (
            FIFOSIZE : integer := 8;
            DATASIZE : integer := 8
        );
        port (
            clk_i     : in  std_logic;
            rst_i     : in  std_logic;
            full_o    : out std_logic;
            empty_o   : out std_logic;
            wr_i      : in  std_logic;
            rd_i      : in  std_logic;
            wr_data_i : in  std_logic_vector(DATASIZE - 1 downto 0);
            rd_data_o : out std_logic_vector(DATASIZE - 1 downto 0)
        );
    end component;

    -------------------------------------------------------------------------------
    -- Helper procedures
    --
    -- All procedures below access signals declared in this architecture region.
    -- They must be called from within a process (wait statements are used).
    -------------------------------------------------------------------------------

    -- Fetch one word from the stimulus channel, present it to the DUT write
    -- port and advance one clock cycle.  wr_sti is left asserted ('1') after
    -- the call; chain with do_wr_idle to deassert between bursts.
    procedure do_write is
        variable data_v : std_logic_vector(DATAWIDTH - 1 downto 0);
    begin
        my_tlm_pkg.blocking_get(fifo_sti, data_v);
        data_in_sti <= data_v;
        wr_sti      <= '1';
        wait until rising_edge(clk_sti);
    end procedure;

    -- Deassert wr_sti and wait n rising edges (write-side idle gap).
    procedure do_wr_idle(n : positive := 1) is
    begin
        wr_sti <= '0';
        for i in 1 to n loop
            wait until rising_edge(clk_sti);
        end loop;
    end procedure;

    -- Assert rd_sti for n consecutive clock cycles (continuous read).
    procedure do_read(n : positive := 1) is
    begin
        rd_sti <= '1';
        for i in 1 to n loop
            wait until rising_edge(clk_sti);
        end loop;
    end procedure;

    -- Deassert rd_sti and wait n rising edges (read-side idle gap).
    procedure do_rd_idle(n : positive := 1) is
    begin
        rd_sti <= '0';
        for i in 1 to n loop
            wait until rising_edge(clk_sti);
        end loop;
    end procedure;

    -- Increment the shared error counter and emit a severity-error message.
    procedure check(condition : boolean; msg : string) is
    begin
        if not condition then
            error_count_v := error_count_v + 1;
            report "FAIL: " & msg severity error;
        end if;
    end procedure;

    -- Final simulation report: called by simulation_monitor at drain time.
    procedure rep(status : finish_status_t) is
    begin
        if error_count_v = 0 then
            report "Simulation PASSED -- 0 errors." severity note;
        else
            report "Simulation FAILED -- " &
                   integer'image(error_count_v) & " error(s)." severity error;
        end if;
    end rep;

begin

    -- Simulation monitor (TLMVM)
    monitor : simulation_monitor
    generic map(
        drain_time      => 2000 ns,
        beat_time       => 2000 ns,
        final_reporting => rep
    );

    -- Clock and reset generation (TLMVM helpers)
    clock_generator(clk_sti, CLK_PERIOD);
    simple_startup_reset(rst_sti, CLK_PERIOD * 10);

    -- Device under test
    DUT : fifo
    generic map(
        FIFOSIZE => FIFOSIZE,
        DATASIZE => DATAWIDTH
    )
    port map(
        clk_i     => clk_sti,
        rst_i     => rst_sti,
        full_o    => full_obs,
        empty_o   => empty_obs,
        wr_i      => wr_sti,
        rd_i      => rd_sti,
        wr_data_i => data_in_sti,
        rd_data_o => data_out_obs
    );

    ---------------------------------------------------------------------------
    -- Driver process
    -- Reads transactions from fifo_sti and drives the DUT write port.
    ---------------------------------------------------------------------------
    driver_process : process is
        variable data_v : std_logic_vector(DATAWIDTH - 1 downto 0);
    begin
        wr_sti <= '0';
        wait until rst_sti = '0';
        wait until rising_edge(clk_sti);

        case TESTCASE is

            when 1 | 2 =>
                report "TC1/2: 2 writes, 1-cycle pause, 4 writes" severity note;
                do_write; do_write;
                do_wr_idle;
                do_write; do_write; do_write; do_write;

            when 3 =>
                report "TC3: 2 writes, 2-cycle pause, 5 writes" severity note;
                do_write; do_write;
                do_wr_idle(2);
                do_write; do_write; do_write; do_write; do_write;

            when 4 =>
                report "TC4: 3 writes, 1-cycle pause, 5 writes" severity note;
                do_write; do_write; do_write;
                do_wr_idle;
                do_write; do_write; do_write; do_write; do_write;

            when 5 =>
                report "TC5: 2 writes only (read-past-empty expected)" severity note;
                do_write; do_write;

            when 6 =>
                report "TC6: 5 consecutive writes" severity note;
                do_write; do_write; do_write; do_write; do_write;

            when 7 =>
                report "TC7: 3 writes, 1-cycle pause, 4 writes" severity note;
                do_write; do_write; do_write;
                do_wr_idle;
                do_write; do_write; do_write; do_write;

            when 8 =>
                report "TC8: 4 writes then stop" severity note;
                do_write; do_write; do_write; do_write;

            when 9 | 10 =>
                report "TC9/10: 3 writes, 1-cycle pause, 3 writes" severity note;
                do_write; do_write; do_write;
                do_wr_idle;
                do_write; do_write; do_write;

            when 11 | 12 =>
                report "TC11/12: fill FIFO completely (" &
                       integer'image(FIFOSIZE) & " writes)" severity note;
                do_write; do_write; do_write; do_write;
                do_write; do_write; do_write; do_write;

            when 13 =>
                report "TC13: 3 writes then long pause" severity note;
                do_write; do_write; do_write;

            when 0 =>
                report "TC0: random stimulus (" &
                       integer'image(NUMBER_OF_TRANSACTIONS) &
                       " transactions)" severity note;
                loop
                    my_tlm_pkg.blocking_get(fifo_sti, data_v);
                    wait until falling_edge(clk_sti);
                    if full_obs = '1' then
                        wait until full_obs = '0';
                    end if;
                    data_in_sti <= data_v;
                    wr_sti      <= '1';
                    wait until rising_edge(clk_sti);
                end loop;

            when others => null;
        end case;

        wr_sti <= '0';
        wait;
    end process driver_process;

    ---------------------------------------------------------------------------
    -- Observer process
    -- Captures valid DUT read-port output into fifo_obs for later comparison.
    ---------------------------------------------------------------------------
    observer_process : process is
        variable ok : boolean;
    begin
        loop
            wait until rising_edge(clk_sti);
            if empty_obs = '0' and rd_sti = '1' then
                fifo_obs.put(data_out_obs, ok);
                check(ok, "Observer: failed to enqueue observation");
            end if;
        end loop;
    end process observer_process;

    ---------------------------------------------------------------------------
    -- Reader process
    -- Drives the DUT rd_i port according to the selected testcase.
    ---------------------------------------------------------------------------
    reader_process : process is
        variable rnd_100 : Uniform := InitUniform(7, 0.0, 3.0);
    begin
        rd_sti <= '0';
        wait until rst_sti = '0';
        wait until rising_edge(clk_sti);

        case TESTCASE is

            when 1 =>
                -- 2-cycle wait, single read, 1-cycle gap, 3 more reads
                do_rd_idle(2);
                do_read(1); do_rd_idle(1); do_read(3);

            when 2 =>
                -- 2-cycle wait then drain continuously
                do_rd_idle(2);
                do_read(5);

            when 3 =>
                -- read 2, 2-cycle gap, read 3
                do_rd_idle(2);
                do_read(2); do_rd_idle(2); do_read(3);

            when 4 =>
                -- 3-cycle wait then drain continuously
                do_rd_idle(3);
                do_read(7);

            when 5 =>
                -- start reading before FIFO drains (tests empty behaviour)
                do_rd_idle(2);
                do_read(7);

            when 6 =>
                -- read 1, 1-cycle gap, read 3
                do_rd_idle(1);
                do_read(1); do_rd_idle(1); do_read(3);

            when 7 | 8 =>
                -- read 2, 1-cycle gap, read 3
                do_rd_idle(2);
                do_read(2); do_rd_idle(1); do_read(3);

            when 9 =>
                -- read 1, 1-cycle gap, read 4
                do_rd_idle(2);
                do_read(1); do_rd_idle(1); do_read(4);

            when 10 | 11 =>
                -- 2-cycle wait then continuous drain
                do_rd_idle(2);
                do_read(6);

            when 12 =>
                -- 1-cycle wait then continuous drain (one cycle earlier than TC11)
                do_rd_idle(1);
                do_read(6);

            when 13 =>
                -- late drain: 3-cycle wait then 6 reads
                do_rd_idle(3);
                do_read(6);

            when 0 =>
                -- Wait until full, then burst-read, then random reads
                rd_sti <= '0';
                wait until full_obs = '1' and falling_edge(clk_sti);

                for i in 1 to 15 loop
                    wait until falling_edge(clk_sti);
                    rd_sti <= '1';
                end loop;

                rd_sti <= '0';
                for i in 1 to 15 loop
                    GenRnd(rnd_100);
                    wait for integer(rnd_100.rnd) * CLK_PERIOD;
                    wait until falling_edge(clk_sti);
                    rd_sti <= '1';
                    wait until rising_edge(clk_sti);
                    rd_sti <= '0';
                end loop;

            when others => null;
        end case;

        rd_sti <= '0';
        wait;
    end process reader_process;

    ---------------------------------------------------------------------------
    -- Stimulation process
    -- Fills fifo_sti (for the driver) and fifo_ref (for verification) with
    -- NUMBER_OF_TRANSACTIONS sequential values.
    ---------------------------------------------------------------------------
    stimulation_process : process is
    begin
        for i in 1 to NUMBER_OF_TRANSACTIONS loop
            raise_objection;
            my_tlm_pkg.blocking_put(fifo_sti,
                std_logic_vector(to_unsigned(i, DATAWIDTH)));
            drop_objection;
            my_tlm_pkg.blocking_put(fifo_ref,
                std_logic_vector(to_unsigned(i, DATAWIDTH)));
        end loop;
        wait;
    end process stimulation_process;

    ---------------------------------------------------------------------------
    -- Verification process
    -- Compares every word captured by the observer against the reference.
    -- Reports data mismatches and over-read conditions via check().
    ---------------------------------------------------------------------------
    verification_process : process is
        variable data_obs_v : std_logic_vector(DATAWIDTH - 1 downto 0);
        variable data_ref_v : std_logic_vector(DATAWIDTH - 1 downto 0);
        variable read_count : integer := 0;
    begin
        loop
            my_tlm_pkg.blocking_get(fifo_obs, data_obs_v);
            read_count := read_count + 1;

            check(read_count <= NUMBER_OF_TRANSACTIONS,
                  "More words read than generated (" &
                  integer'image(read_count) & " > " &
                  integer'image(NUMBER_OF_TRANSACTIONS) & ")");

            my_tlm_pkg.blocking_get(fifo_ref, data_ref_v);

            check(data_obs_v = data_ref_v,
                  "Data mismatch at read #" & integer'image(read_count) &
                  ": expected 0x" & to_hstring(data_ref_v) &
                  ", got 0x"      & to_hstring(data_obs_v));
        end loop;
    end process verification_process;

end test_bench;
