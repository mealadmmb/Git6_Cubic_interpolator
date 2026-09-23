----------------------------------------------------------------------------------
-- Module Name: resampler_cubic_catmull
-- Target Device: Xilinx Zynq-7000 (XC7Z020, Speed Grade -2)
-- Description:
--   Autonomous Streaming Resampler module with 100% SIGNALS and ZERO VARIABLES.
--   - Registered input boundary to eliminate Hold timing violations
--   - Distributed LUTRAM buffer (0 Block RAMs consumed)
--   - Dynamic runtime phase_step input port
--   - Fully pipelined Catmull-Rom cubic core
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity resampler_cubic_catmull is
    port (
        clk        : in  std_logic;
        rst_n      : in  std_logic;
        -- Dynamic Runtime Resampling Rate Configuration
        -- phase_step = round(2^32 / R)
        phase_step : in  unsigned(31 downto 0);
        -- Streaming Input Sample Interface
        in_valid   : in  std_logic;
        in_i       : in  signed(15 downto 0);
        in_q       : in  signed(15 downto 0);
        in_ready   : out std_logic;
        -- Streaming Resampled Output Interface
        out_valid  : out std_logic;
        out_i      : out signed(15 downto 0);
        out_q      : out signed(15 downto 0)
    );
end entity resampler_cubic_catmull;

architecture rtl of resampler_cubic_catmull is

    -- Input Registration Stage for Robust IOB & Hold Timing
    signal phase_step_reg : unsigned(31 downto 0) := (others => '0');
    signal in_valid_reg   : std_logic := '0';
    signal in_i_reg       : signed(15 downto 0) := (others => '0');
    signal in_q_reg       : signed(15 downto 0) := (others => '0');

    -- 256-word circular buffer (Distributed LUTRAM / 0 Block RAM)
    type sample_ram_t is array (0 to 255) of signed(15 downto 0);
    signal ram_i : sample_ram_t := (others => (others => '0'));
    signal ram_q : sample_ram_t := (others => (others => '0'));

    attribute ram_style : string;
    attribute ram_style of ram_i : signal is "distributed";
    attribute ram_style of ram_q : signal is "distributed";

    signal wr_ptr    : unsigned(7 downto 0) := (others => '0');
    signal rd_k      : unsigned(7 downto 0) := to_unsigned(1, 8);
    signal count_buf : unsigned(7 downto 0) := (others => '0');

    -- NCO Signals (Pure Signals, No Variables)
    signal phase_acc   : unsigned(31 downto 0) := (others => '0');
    signal next_phase  : unsigned(32 downto 0) := (others => '0');
    signal phase_carry : std_logic := '0';
    signal mu_val      : unsigned(15 downto 0) := (others => '0');

    -- Core Interface Signals
    signal core_valid_in : std_logic := '0';
    signal ym1_i, y0_i, y1_i, y2_i : signed(15 downto 0) := (others => '0');
    signal ym1_q, y0_q, y1_q, y2_q : signed(15 downto 0) := (others => '0');

    -- Component declaration
    component cubic_catmull_core is
        port (
            clk       : in  std_logic;
            rst_n     : in  std_logic;
            in_valid  : in  std_logic;
            ym1_i     : in  signed(15 downto 0);
            y0_i      : in  signed(15 downto 0);
            y1_i      : in  signed(15 downto 0);
            y2_i      : in  signed(15 downto 0);
            ym1_q     : in  signed(15 downto 0);
            y0_q      : in  signed(15 downto 0);
            y1_q      : in  signed(15 downto 0);
            y2_q      : in  signed(15 downto 0);
            mu        : in  unsigned(15 downto 0);
            out_valid : out std_logic;
            out_i     : out signed(15 downto 0);
            out_q     : out signed(15 downto 0)
        );
    end component;

begin

    -- Buffer accepts new input samples as long as it is not near full
    in_ready <= '1' when (count_buf < 240) else '0';

    -- Concurrent NCO Next Phase Computation
    next_phase  <= ('0' & phase_acc) + ('0' & phase_step_reg);
    phase_carry <= next_phase(32);

    -- Instantiate Interpolation Core
    u_core: cubic_catmull_core
        port map (
            clk       => clk,
            rst_n     => rst_n,
            in_valid  => core_valid_in,
            ym1_i     => ym1_i,
            y0_i      => y0_i,
            y1_i      => y1_i,
            y2_i      => y2_i,
            ym1_q     => ym1_q,
            y0_q      => y0_q,
            y1_q      => y1_q,
            y2_q      => y2_q,
            mu        => mu_val,
            out_valid => out_valid,
            out_i     => out_i,
            out_q     => out_q
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                phase_step_reg <= (others => '0');
                in_valid_reg   <= '0';
                in_i_reg       <= (others => '0');
                in_q_reg       <= (others => '0');
                wr_ptr         <= (others => '0');
                rd_k           <= to_unsigned(1, 8);
                count_buf      <= (others => '0');
                phase_acc      <= (others => '0');
                core_valid_in  <= '0';
                mu_val         <= (others => '0');
                ym1_i          <= (others => '0');
                y0_i           <= (others => '0');
                y1_i           <= (others => '0');
                y2_i           <= (others => '0');
                ym1_q          <= (others => '0');
                y0_q           <= (others => '0');
                y1_q           <= (others => '0');
                y2_q           <= (others => '0');
            else
                -- 1. Input Registration Stage
                phase_step_reg <= phase_step;
                in_valid_reg   <= in_valid;
                in_i_reg       <= in_i;
                in_q_reg       <= in_q;

                -- 2. Buffer Write Process
                if in_valid_reg = '1' and count_buf < 240 then
                    ram_i(to_integer(wr_ptr)) <= in_i_reg;
                    ram_q(to_integer(wr_ptr)) <= in_q_reg;
                    wr_ptr <= wr_ptr + 1;
                end if;

                -- 3. Automatic Resampling Process
                if (wr_ptr > rd_k + 2) and (rd_k <= 197) then
                    ym1_i <= ram_i(to_integer(rd_k - 1));
                    y0_i  <= ram_i(to_integer(rd_k));
                    y1_i  <= ram_i(to_integer(rd_k + 1));
                    y2_i  <= ram_i(to_integer(rd_k + 2));

                    ym1_q <= ram_q(to_integer(rd_k - 1));
                    y0_q  <= ram_q(to_integer(rd_k));
                    y1_q  <= ram_q(to_integer(rd_k + 1));
                    y2_q  <= ram_q(to_integer(rd_k + 2));

                    mu_val        <= phase_acc(31 downto 16);
                    core_valid_in <= '1';

                    -- Update NCO Phase
                    phase_acc <= next_phase(31 downto 0);

                    -- Advance sample pointer when crossing integer threshold
                    if phase_carry = '1' then
                        rd_k <= rd_k + 1;
                        if in_valid_reg = '0' and count_buf > 0 then
                            count_buf <= count_buf - 1;
                        end if;
                    else
                        if in_valid_reg = '1' and count_buf < 240 then
                            count_buf <= count_buf + 1;
                        end if;
                    end if;
                else
                    core_valid_in <= '0';
                    if in_valid_reg = '1' and count_buf < 240 then
                        count_buf <= count_buf + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
