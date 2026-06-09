# VHDL snippets — SCF exam cheat sheet

Patterns reused across labo5 (AXI slave), labo8 (FIR), labo9 (convolution).  
Each section explains **what the code does**, **why it is written that way**, and **when you need it** in the exam.

Course references: `labo5/axi4lite_io/hard/src/axi4lite_slave.vhd`, `labo8/src_vhdl/`, `labo9` / `Labo_scf_2024/labo9`.

---

## 1. File header + libraries

```vhdl
-- synthesis VHDL_INPUT_VERSION VHDL_2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;   -- signed, unsigned, resize, shift_*
-- use ieee.math_real.all;  -- only if you need log2 / ceil (conv_engine)
```

### What it does

- `library ieee` — standard types (`std_logic`, `std_logic_vector`).
- `numeric_std` — **required** for arithmetic on vectors (`+`, `*`, `resize`, `shift_right`). Without it you cannot legally multiply signed samples and coefficients.
- `math_real` — only for compile-time math (e.g. computing accumulator bit width from kernel size).
- The `-- synthesis VHDL_INPUT_VERSION VHDL_2008` line tells Quartus to accept VHDL-2008 features (`process (all)`, `for … loop` in comb logic, etc.).

### When to use

- **Every** FPGA file in the exam project.
- Enable VHDL-2008 in Quartus project settings too; the attribute alone is not always enough.

---

## 2. Exam constants

```vhdl
constant CST_CONSTANT : std_logic_vector(31 downto 0) := x"BADB100D";  -- labo7
-- constant CST_CONSTANT : std_logic_vector(31 downto 0) := x"D06512ED";  -- labo9
constant CST_BAD_ADDR : std_logic_vector(31 downto 0) := x"BADCAB1E";  -- unmapped read
```

### What it does

- **`CST_CONSTANT`** — returned when software reads register index 0. The Linux driver reads this at `insmod` time; if the value is wrong, the driver refuses to load (`invalid CST`). Proves the correct bitstream is loaded and the base address matches.
- **`CST_BAD_ADDR`** — default value for illegal or unused addresses. Helps debug: if `devmem` returns `BADCAB1E`, you read an unmapped register index.

### When to use

- Always define both in `axi4lite_slave.vhd`.
- Pick the constant value from the exam subject and copy the **same hex** into `axi_regs.h` / driver `AXI_CONSTANT`.
- labo7/labo5 use `BADB100D`; labo9 convolution uses `D06512ED`.

---

## 3. Synchronous reset (register bank)

```vhdl
process (rst_i, clk_i)
begin
    if rst_i = '1' then
        my_reg <= (others => '0');
    elsif rising_edge(clk_i) then
        my_reg <= next_val;   -- single assignment per signal per branch
    end if;
end process;
```

### What it does

- On reset (`rst_i = '1'`), all registers go to zero **before** the next clock edge.
- On each rising clock edge, registers update to their next value.
- This is the standard pattern for **storing state** in the FPGA: coefficient registers, FIFO pointers, FSM state, delay lines.

### Why `process (rst_i, clk_i)`

- Sensitivity list must include `rst_i` so reset is asynchronous to the clock in simulation (sync reset still uses `if rst_i` inside the process — labo5 style).

### When to use

- Any signal that must **remember** a value: `test_s`, `param_0_s`, line buffers, FSM `state`, output valid flags.
- **Do not** put combinational MAC math here if you have many taps — use a separate `process (all)` or FSM (see guide 06).

### One-cycle command pulse (reset FIFO / datapath)

```vhdl
if cmd_reset_pulse = '1' then
    fifo_ptr <= 0;
end if;
-- in write case: cmd_reset_pulse <= wdata(31); then clear pulse next cycle
```

**What it does:** Software writes bit 31 of the control register; hardware clears internal buffers on that cycle.  
**When to use:** Exam `ioctl` reset (2024 FIR, labo9 conv) — flush delay lines and output FIFO without reloading the bitstream.

---

## 4. AXI register write `case` (word index)

Address **word index** = `to_integer(unsigned(axi_waddr_mem_s))` (labo5 EMI slave).

```vhdl
process (rst_i, clk_i)
    variable idx : natural;
begin
    if rst_i = '1' then
        test_s    <= (others => '0');
        param_0_s <= (others => '0');
    elsif rising_edge(clk_i) then
        if axi_data_wren_s = '1' then
            idx := to_integer(unsigned(axi_waddr_mem_s));
            case idx is
                when 0 => null;  -- constant: read-only
                when 1 => test_s <= axi_wdata_i;
                when 2 =>
                    if axi_wstrb_i(3) = '1' then
                        cmd_reset_s <= axi_wdata_i(31);
                    end if;
                when 3 => param_0_s <= axi_wdata_i;
                when 6 => data_in_s <= axi_wdata_i;
                when others => null;
            end case;
        end if;
    end if;
end process;
```

### What it does

| Line / branch | Meaning |
|---------------|---------|
| `axi_data_wren_s = '1'` | AXI write handshake complete — address and data are valid this cycle. |
| `idx := … axi_waddr_mem_s` | Convert byte address to **word index** (0, 1, 2…). Offset `0x08` → index `2`. |
| `when 0 => null` | Constant register is read-only; writes ignored. |
| `when 1` | Test register — driver uses this for bring-up R/W check. |
| `when 2` + `wstrb_i(3)` | Only byte 3 (MSB) can set reset bit — matches 32-bit control reg layout. |
| `when 3` | Store coefficient / kernel / parameter from software. |
| `when 6` | **Data path input** — each write pushes a sample or 4-byte chunk into your FIR/conv logic. |

### When to use

- **Core of every exam AXI slave** — this is how the HPS (ARM) talks to your custom logic.
- Driver `iowrite32(base + index*4, val)` must match your `when` indices exactly.
- Extend the `case` for each register on the exam address map; do not change labo5 AW/W channel FSM unless you know why.

### Typical exam flow

1. Driver writes `PARAM_0..2` (coefficients).
2. Userspace `write()` → driver writes `DATA_IN` (index 6).
3. Your datapath computes; result visible on `DATA_OUT` read.

---

## 5. AXI read mux — `process (all)` (VHDL-2008)

```vhdl
process (all)
    variable idx : natural;
begin
    idx := to_integer(unsigned(axi_araddr_mem_s));
    axi_rdata_s <= CST_BAD_ADDR;
    pop_fifo_s  <= '0';

    case idx is
        when 0 => axi_rdata_s <= CST_CONSTANT;
        when 1 => axi_rdata_s <= test_s;
        when 2 =>
            axi_rdata_s(0) <= running_s;
            axi_rdata_s(1) <= done_s;
            axi_rdata_s(31 downto 2) <= (others => '0');
        when 7 =>
            axi_rdata_s <= std_logic_vector(resize(data_out_s, 32));
            if axi_data_rden_s = '1' then
                pop_fifo_s <= '1';
            end if;
        when others => null;
    end case;
end process;
```

### What it does

- **`process (all)`** — recomputes whenever any read input changes (address, FIFO content, status flags). This is **combinational** read mux logic.
- Default `axi_rdata_s <= CST_BAD_ADDR` — safe fallback for bad addresses.
- **`when 2`** — packs status bits into one word; driver/userspace polls `done`, `empty`, etc. without extra registers.
- **`when 7` + `pop_fifo_s`** — reading output data also dequeues the FIFO (labo9 pattern). `pop_fifo_s` is registered in a second process that runs when `axi_data_rden_s` confirms the read.

A **second** clocked process (not shown) does `if axi_data_rden_s = '1' then axi_rdata_o <= axi_rdata_s` — output is stable for the AXI read data phase.

### When to use

- Every register the software **reads**: constant, status, output data, readable coeffs.
- Use `pop_fifo_s` when output is a **queue** (streaming conv); skip it when output is a single holding register (simple FIR).

---

## 6. Shift register (FIR delay line / sample history)

3-tap FIR needs current sample `x` and two past samples `x1`, `x2`:

```vhdl
type delay_line_t is array (0 to 2) of signed(7 downto 0);
signal x_delay : delay_line_t := (others => (others => '0'));

process (rst_i, clk_i)
begin
    if rst_i = '1' then
        x_delay <= (others => (others => '0'));
    elsif rising_edge(clk_i) then
        if sample_valid = '1' then
            x_delay(0) <= signed(new_sample);
            x_delay(1) <= x_delay(0);
            x_delay(2) <= x_delay(1);
        end if;
    end if;
end process;
```

### What it does

Each valid sample shifts the chain:

```
Before:  x_delay = [x1, x2, x3]
After:   x_delay = [new, x1, x2]
```

- `x_delay(0)` — newest sample.
- `x_delay(2)` — oldest of the three (for 3-tap FIR: that is `x[n-2]`).

### When to use

- **2024 FIR exam** — mandatory; equation needs `x[n]`, `x[n-1]`, `x[n-2]`.
- Trigger `sample_valid` when `DATA_IN` is written (or when one byte of the 4-byte word is consumed).
- On reset command, clear `x_delay` to avoid garbage in first outputs.

### Generic `ORDER`-tap (labo8)

```vhdl
for i in 1 to ORDER loop
    x_reg(i) <= x_reg(i - 1);
end loop;
x_reg(0) <= signed(din_i);
```

**When to use:** FIR with more than 3 taps (labo8). Same idea, longer chain.

---

## 7. Signed multiply-accumulate (3-tap FIR)

```vhdl
process (all)
    variable acc : signed(31 downto 0);
begin
    acc := (others => '0');
    acc := acc + resize(c0 * x_delay(0), acc'length);
    acc := acc + resize(c1 * x_delay(1), acc'length);
    acc := acc + resize(c2 * x_delay(2), acc'length);
    y_s <= acc(7 downto 0);   -- or resize / shift for fractional coeffs
end process;
```

### What it does

- Computes `y = C0·x + C1·x1 + C2·x2` in **one combinational pass**.
- `resize(..., acc'length)` — widen products before add so bits are not lost.
- `acc(7 downto 0)` — take LSB byte as output pixel/sample (exam often uses 8-bit data).

### When to use

- **Default datapath for 2024-style 3-tap FIR** inside `axi4lite_slave` or a small `fir_engine` entity.
- Connect `c0..c2` to registers written from software (`param_0_s` etc.).
- Recompute whenever `x_delay` or coefficients change — result ready same cycle (combinational style; see guide 06).

### Why `signed`

Kernel/coeff values can be negative (e.g. `-1, 0, 4` sharpen filter). `unsigned` would wrap incorrectly on negative values.

---

## 8. 3×3 convolution (nested loops)

```vhdl
process (all)
    variable sum_v : integer;
begin
    sum_v := 0;
    for row in 0 to 2 loop
        for col in 0 to 2 loop
            sum_v := sum_v + to_integer(window(row, col)) * kernel(row, col);
        end loop;
    end loop;
    result_s <= to_signed(sum_v, 20);   -- width >= DATASIZE_IN + DATASIZE_KER + log2(9)
end process;
```

### What it does

- `window(0..2, 0..2)` — nine pixel values around the current position (3 rows × 3 columns).
- `kernel(row,col)` — coefficient at that position (from registers or package).
- Nested loops sum all nine products — standard 2D convolution MAC.

### When to use

- **labo9 / convolution exam** — put this in `conv_engine` entity; feed `window` from line buffers in the AXI slave.
- Small fixed 3×3 kernel → combinational is fine at 50 MHz.
- **Not** for huge kernels (5×5, 7×7) without pipelining — logic depth grows fast.

### Where `window` comes from

Separate sequential processes shift image rows (line buffers). When enough pixels arrived, fill `window` and assert `compute_i` to `conv_engine`.

---

## 9. Two-process FSM (sequential controller)

Used when one multiplier is reused over many taps (labo8 sequential FIR).

### Process 1 — registered state + datapath (clocked)

```vhdl
process (rst_i, clk_i)
begin
    if rst_i = '1' then
        state   <= IDLE;
        k_count <= 0;
        acc_reg <= (others => '0');
    elsif rising_edge(clk_i) then
        state <= next_state;
        if acc_en = '1' then
            acc_reg <= acc_reg + resize(product, acc_reg'length);
        end if;
        if k_inc = '1' and k_count < ORDER then
            k_count <= k_count + 1;
        end if;
    end if;
end process;
```

**What it does:** On each clock edge, updates FSM state, accumulator, and tap counter **only when** enable signals say so.  
**When to use:** Large `ORDER`, area-saving design, or when comb MAC does not meet timing (rare at 50 MHz for exam sizes).

### Process 2 — combinational next state + control (no clock)

```vhdl
process (state, din_valid_i, k_count)
begin
    next_state   <= state;
    acc_en       <= '0';
    k_inc        <= '0';
    dout_valid_o <= '0';

    case state is
        when IDLE =>
            if din_valid_i = '1' then
                next_state <= MAC;
            end if;
        when MAC =>
            acc_en <= '1';
            if k_count = ORDER then
                next_state <= OUTPUT;
            else
                k_inc <= '1';
            end if;
        when OUTPUT =>
            dout_valid_o <= '1';
            next_state   <= IDLE;
    end case;
end process;
```

**What it does:** From current `state`, decides **next** state and control signals (`acc_en`, `k_inc`). Defaults every line to `'0'` so you only enable what you need.  
**When to use:** Sequential FIR (labo8 `fir_filter__seq.vhd`). Usually **overkill** for 3-tap exam FIR — prefer section 7 instead.

Full example: `labo8/src_vhdl/fir_filter__seq.vhd`.

---

## 10. Valid / ready handshake (streaming)

```vhdl
-- Producer accepts when downstream ready or output empty
din_ready_o <= '1' when dout_ready_i = '1' or not dout_valid_reg else '0';

-- Register output valid until consumer asserts ready
if dout_ready_i = '1' then
    dout_valid_reg <= '0';
elsif mac_done = '1' then
    dout_valid_reg <= '1';
end if;
```

### What it does

- **`din_ready_o`** — upstream may send only when downstream can accept (back-pressure).
- **`dout_valid_reg`** — holds high until consumer acknowledges with `dout_ready_i`.
- Prevents overwriting a result before software/`read()` consumes it.

### When to use

- Streaming IP with continuous samples (pipeline FIR, video conv).
- **2024 FIR with IRQ:** tie `irq_o` to `dout_valid_reg` — interrupt fires when new output ready; ISR or userspace then `read()`s `DATA_OUT`.
- **Skip** if exam only polls status register — simpler `data_out_valid` flag is enough.

---

## 11. Package for array types

```vhdl
package my_ip_pkg is
    constant DATASIZE : integer := 8;
    type sample_array_t is array (natural range <>) of signed(DATASIZE - 1 downto 0);
    type kernel_array_t is array (natural range <>, natural range <>) of integer;
end package my_ip_pkg;
```

### What it does

- Centralises bit widths and array types used by entity + architecture.
- `conv_engine` and `axi4lite_slave` both `use work.my_ip_pkg.all` — same `window` type everywhere.

### When to use

- More than one VHDL file shares types (labo9: `conv_engine_pkg.vhd`).
- Optional for tiny 3-tap FIR in a single file; helpful when Qsys lists multiple files in `IP_hw.tcl`.

---

## 12. Common mistakes

| Mistake | What goes wrong | Fix |
|---------|-----------------|-----|
| `integer` overflow in conv sum | Wrong pixel values, hard to debug | Result width ≥ input + coeff + log2(num_products) |
| Multiple drivers on same signal | Quartus error or latch | One clocked process per register |
| Wrong sensitivity list | Sim ≠ synthesis | `process (rst_i, clk_i)` for sync registers |
| Unsigned × signed mix | Negative coeffs become huge positive | Cast with `signed()` / `unsigned()` |
| AXI addr off by 4 | Driver reads wrong register | VHDL `case` uses **word** index; C uses `REG_*` same index |
| Huge comb loop in exam | Timing fail | ≤16 products comb OK; else sequential FSM |

---

## See also

- [06_vhdl_comb_pipe_seq.md](06_vhdl_comb_pipe_seq.md) — when to pick comb / pipeline / sequential for the datapath
- [01_qsys_platform_designer.md](01_qsys_platform_designer.md) — hooking `axi4lite_slave` into Qsys
