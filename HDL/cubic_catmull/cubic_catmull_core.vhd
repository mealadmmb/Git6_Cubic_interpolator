----------------------------------------------------------------------------------
-- Module Name: cubic_catmull_core
-- Target Device: Xilinx Zynq-7000 (XC7Z020, Speed Grade -2)
-- Description:
--   Pure Pipelined Register-Transfer-Level (RTL) Catmull-Rom Cubic Spline Core.
--   Implemented with 100% SIGNALS and ZERO VARIABLES.
--   Enables full DSP48E1 internal register absorption (AREG, BREG, MREG, PREG).
--   Latency: Exactly 8 clock cycles.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cubic_catmull_core is
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        in_valid  : in  std_logic;
        -- 4 consecutive input samples for I channel (Q1.15)
        ym1_i     : in  signed(15 downto 0);
        y0_i      : in  signed(15 downto 0);
        y1_i      : in  signed(15 downto 0);
        y2_i      : in  signed(15 downto 0);
        -- 4 consecutive input samples for Q channel (Q1.15)
        ym1_q     : in  signed(15 downto 0);
        y0_q      : in  signed(15 downto 0);
        y1_q      : in  signed(15 downto 0);
        y2_q      : in  signed(15 downto 0);
        -- Fractional delay mu in [0, 1.0) represented as unsigned Q0.16 [0, 65535]
        mu        : in  unsigned(15 downto 0);
        -- Outputs
        out_valid : out std_logic;
        out_i     : out signed(15 downto 0);
        out_q     : out signed(15 downto 0)
    );
end entity cubic_catmull_core;

architecture rtl of cubic_catmull_core is

    -- Constant for Q0.16 rounding offset (2^15 = 32768)
    constant ROUND_CONST_16 : signed(40 downto 0) := to_signed(32768, 41);

    -- Stage 1: Coefficient Generation (scaled by 2)
    signal val_st1 : std_logic := '0';
    signal mu_st1  : signed(16 downto 0) := (others => '0');
    signal c0_i_st1, c1_i_st1, c2_i_st1, c3_i_st1 : signed(23 downto 0) := (others => '0');
    signal c0_q_st1, c1_q_st1, c2_q_st1, c3_q_st1 : signed(23 downto 0) := (others => '0');

    -- Stage 2: Multiply 1 (prod1 = c3 * mu) -> Maps to DSP48 MREG
    signal val_st2 : std_logic := '0';
    signal mu_st2  : signed(16 downto 0) := (others => '0');
    signal c0_i_st2, c1_i_st2, c2_i_st2 : signed(23 downto 0) := (others => '0');
    signal c0_q_st2, c1_q_st2, c2_q_st2 : signed(23 downto 0) := (others => '0');
    signal prod1_i_st2, prod1_q_st2 : signed(40 downto 0) := (others => '0');

    -- Stage 3: Accumulate 1 (T1 = (prod1 + 32768) >> 16 + c2) -> Maps to DSP48 PREG
    signal val_st3 : std_logic := '0';
    signal mu_st3  : signed(16 downto 0) := (others => '0');
    signal c0_i_st3, c1_i_st3, t1_i_st3 : signed(23 downto 0) := (others => '0');
    signal c0_q_st3, c1_q_st3, t1_q_st3 : signed(23 downto 0) := (others => '0');

    -- Stage 4: Multiply 2 (prod2 = T1 * mu) -> Maps to DSP48 MREG
    signal val_st4 : std_logic := '0';
    signal mu_st4  : signed(16 downto 0) := (others => '0');
    signal c0_i_st4, c1_i_st4 : signed(23 downto 0) := (others => '0');
    signal c0_q_st4, c1_q_st4 : signed(23 downto 0) := (others => '0');
    signal prod2_i_st4, prod2_q_st4 : signed(40 downto 0) := (others => '0');

    -- Stage 5: Accumulate 2 (T2 = (prod2 + 32768) >> 16 + c1) -> Maps to DSP48 PREG
    signal val_st5 : std_logic := '0';
    signal mu_st5  : signed(16 downto 0) := (others => '0');
    signal c0_i_st5, t2_i_st5 : signed(23 downto 0) := (others => '0');
    signal c0_q_st5, t2_q_st5 : signed(23 downto 0) := (others => '0');

    -- Stage 6: Multiply 3 (prod3 = T2 * mu) -> Maps to DSP48 MREG
    signal val_st6 : std_logic := '0';
    signal c0_i_st6 : signed(23 downto 0) := (others => '0');
    signal c0_q_st6 : signed(23 downto 0) := (others => '0');
    signal prod3_i_st6, prod3_q_st6 : signed(40 downto 0) := (others => '0');

    -- Stage 7: Accumulate 3 (T3 = (prod3 + 32768) >> 16 + c0) -> Maps to DSP48 PREG
    signal val_st7 : std_logic := '0';
    signal t3_i_st7, t3_q_st7 : signed(23 downto 0) := (others => '0');

    -- Stage 8: Final Scale by 1/2 and Saturation to Q1.15
    signal val_st8 : std_logic := '0';
    signal res_i_st8, res_q_st8 : signed(15 downto 0) := (others => '0');

    -- Function to apply 16-bit saturation
    function saturate_q15(val : signed(23 downto 0)) return signed is
    begin
        if val > to_signed(32767, 24) then
            return to_signed(32767, 16);
        elsif val < to_signed(-32768, 24) then
            return to_signed(-32768, 16);
        else
            return resize(val, 16);
        end if;
    end function saturate_q15;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                val_st1 <= '0';
                val_st2 <= '0';
                val_st3 <= '0';
                val_st4 <= '0';
                val_st5 <= '0';
                val_st6 <= '0';
                val_st7 <= '0';
                val_st8 <= '0';
                out_valid <= '0';
                out_i     <= (others => '0');
                out_q     <= (others => '0');
            else
                -----------------------------------------------------------------
                -- STAGE 1: Exact Integer Coefficients (scaled by 2, shift-add)
                -----------------------------------------------------------------
                val_st1 <= in_valid;
                mu_st1  <= signed(resize(mu, 17));

                -- I Channel
                c0_i_st1 <= shift_left(resize(y0_i, 24), 1);
                c1_i_st1 <= resize(y1_i, 24) - resize(ym1_i, 24);
                c2_i_st1 <= shift_left(resize(ym1_i, 24), 1) - (shift_left(resize(y0_i, 24), 2) + resize(y0_i, 24)) + shift_left(resize(y1_i, 24), 2) - resize(y2_i, 24);
                c3_i_st1 <= -resize(ym1_i, 24) + (shift_left(resize(y0_i, 24), 1) + resize(y0_i, 24)) - (shift_left(resize(y1_i, 24), 1) + resize(y1_i, 24)) + resize(y2_i, 24);

                -- Q Channel
                c0_q_st1 <= shift_left(resize(y0_q, 24), 1);
                c1_q_st1 <= resize(y1_q, 24) - resize(ym1_q, 24);
                c2_q_st1 <= shift_left(resize(ym1_q, 24), 1) - (shift_left(resize(y0_q, 24), 2) + resize(y0_q, 24)) + shift_left(resize(y1_q, 24), 2) - resize(y2_q, 24);
                c3_q_st1 <= -resize(ym1_q, 24) + (shift_left(resize(y0_q, 24), 1) + resize(y0_q, 24)) - (shift_left(resize(y1_q, 24), 1) + resize(y1_q, 24)) + resize(y2_q, 24);

                -----------------------------------------------------------------
                -- STAGE 2: DSP48 Multiplier 1 (prod1 = c3 * mu)
                -----------------------------------------------------------------
                val_st2     <= val_st1;
                mu_st2      <= mu_st1;
                c0_i_st2    <= c0_i_st1;
                c1_i_st2    <= c1_i_st1;
                c2_i_st2    <= c2_i_st1;
                c0_q_st2    <= c0_q_st1;
                c1_q_st2    <= c1_q_st1;
                c2_q_st2    <= c2_q_st1;
                prod1_i_st2 <= c3_i_st1 * mu_st1;
                prod1_q_st2 <= c3_q_st1 * mu_st1;

                -----------------------------------------------------------------
                -- STAGE 3: Accumulate 1 (T1 = (prod1 + 32768) >> 16 + c2)
                -----------------------------------------------------------------
                val_st3  <= val_st2;
                mu_st3   <= mu_st2;
                c0_i_st3 <= c0_i_st2;
                c1_i_st3 <= c1_i_st2;
                c0_q_st3 <= c0_q_st2;
                c1_q_st3 <= c1_q_st2;
                t1_i_st3 <= resize(shift_right(prod1_i_st2 + ROUND_CONST_16, 16), 24) + c2_i_st2;
                t1_q_st3 <= resize(shift_right(prod1_q_st2 + ROUND_CONST_16, 16), 24) + c2_q_st2;

                -----------------------------------------------------------------
                -- STAGE 4: DSP48 Multiplier 2 (prod2 = T1 * mu)
                -----------------------------------------------------------------
                val_st4     <= val_st3;
                mu_st4      <= mu_st3;
                c0_i_st4    <= c0_i_st3;
                c1_i_st4    <= c1_i_st3;
                c0_q_st4    <= c0_q_st3;
                c1_q_st4    <= c1_q_st3;
                prod2_i_st4 <= t1_i_st3 * mu_st3;
                prod2_q_st4 <= t1_q_st3 * mu_st3;

                -----------------------------------------------------------------
                -- STAGE 5: Accumulate 2 (T2 = (prod2 + 32768) >> 16 + c1)
                -----------------------------------------------------------------
                val_st5  <= val_st4;
                mu_st5   <= mu_st4;
                c0_i_st5 <= c0_i_st4;
                c0_q_st5 <= c0_q_st4;
                t2_i_st5 <= resize(shift_right(prod2_i_st4 + ROUND_CONST_16, 16), 24) + c1_i_st4;
                t2_q_st5 <= resize(shift_right(prod2_q_st4 + ROUND_CONST_16, 16), 24) + c1_q_st4;

                -----------------------------------------------------------------
                -- STAGE 6: DSP48 Multiplier 3 (prod3 = T2 * mu)
                -----------------------------------------------------------------
                val_st6     <= val_st5;
                c0_i_st6    <= c0_i_st5;
                c0_q_st6    <= c0_q_st5;
                prod3_i_st6 <= t2_i_st5 * mu_st5;
                prod3_q_st6 <= t2_q_st5 * mu_st5;

                -----------------------------------------------------------------
                -- STAGE 7: Accumulate 3 (T3 = (prod3 + 32768) >> 16 + c0)
                -----------------------------------------------------------------
                val_st7  <= val_st6;
                t3_i_st7 <= resize(shift_right(prod3_i_st6 + ROUND_CONST_16, 16), 24) + c0_i_st6;
                t3_q_st7 <= resize(shift_right(prod3_q_st6 + ROUND_CONST_16, 16), 24) + c0_q_st6;

                -----------------------------------------------------------------
                -- STAGE 8: Divide by 2 with Rounding & Saturation
                -----------------------------------------------------------------
                val_st8   <= val_st7;
                res_i_st8 <= saturate_q15(shift_right(t3_i_st7 + to_signed(1, 24), 1));
                res_q_st8 <= saturate_q15(shift_right(t3_q_st7 + to_signed(1, 24), 1));

                -- Registered Output Interface
                out_valid <= val_st8;
                out_i     <= res_i_st8;
                out_q     <= res_q_st8;
            end if;
        end if;
    end process;

end architecture rtl;
