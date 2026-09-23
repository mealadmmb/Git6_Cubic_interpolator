----------------------------------------------------------------------------------
-- Testbench Name: tb_cubic_interpolator
-- Description:
--   Streaming Testbench for 4-Point Lagrange Cubic Resampler with dynamic phase_step port.
--   Pushes Q1.15 input samples from sim_data/input_iq.txt using purely 'in_valid'
--   and captures resampled outputs to sim_data/vhdl_lagrange.txt using 'out_valid'.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;

entity tb_cubic_interpolator is
end entity tb_cubic_interpolator;

architecture sim of tb_cubic_interpolator is

    constant CLK_PERIOD : time := 10 ns; -- 100 MHz clock
    constant EXPECTED_OUTPUTS : integer := 769;

    signal clk          : std_logic := '0';
    signal rst_n        : std_logic := '0';
    -- Dynamic phase step input for 3.9x upsampling: round(2^32 / 3.9) = 0x41A41A42
    signal phase_step   : unsigned(31 downto 0) := x"41A41A42";
    signal in_valid     : std_logic := '0';
    signal in_i         : signed(15 downto 0) := (others => '0');
    signal in_q         : signed(15 downto 0) := (others => '0');
    signal in_ready     : std_logic;
    signal out_valid    : std_logic;
    signal out_i        : signed(15 downto 0);
    signal out_q        : signed(15 downto 0);

    signal sim_finished : boolean := false;

begin

    -- Instantiate Device Under Test (DUT)
    uut: entity work.resampler_cubic_lagrange
        port map (
            clk        => clk,
            rst_n      => rst_n,
            phase_step => phase_step,
            in_valid   => in_valid,
            in_i       => in_i,
            in_q       => in_q,
            in_ready   => in_ready,
            out_valid  => out_valid,
            out_i      => out_i,
            out_q      => out_q
        );

    -- Clock Generator
    clk_process: process
    begin
        while not sim_finished loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Stimulus Feeder Process
    stim_process: process
        file in_file : text;
        variable l_in : line;
        variable val_i, val_q : integer;
        variable status : file_open_status;
    begin
        file_open(status, in_file, "sim_data/input_iq.txt", read_mode);
        if status /= open_ok then
            file_open(status, in_file, "../../sim_data/input_iq.txt", read_mode);
        end if;
        assert status = open_ok report "Failed to open sim_data/input_iq.txt" severity failure;

        -- Reset sequence
        rst_n    <= '0';
        in_valid <= '0';
        wait for 40 ns;
        wait until rising_edge(clk);
        rst_n <= '1';
        wait for 20 ns;

        -- Stream input samples directly using in_valid
        while not endfile(in_file) loop
            readline(in_file, l_in);
            read(l_in, val_i);
            read(l_in, val_q);

            wait until rising_edge(clk);
            while in_ready = '0' loop
                in_valid <= '0';
                wait until rising_edge(clk);
            end loop;

            in_i     <= to_signed(val_i, 16);
            in_q     <= to_signed(val_q, 16);
            in_valid <= '1';
        end loop;
        file_close(in_file);

        wait until rising_edge(clk);
        in_valid <= '0';

        while not sim_finished loop
            wait until rising_edge(clk);
        end loop;

        wait;
    end process;

    -- Output Capture Process
    capture_process: process
        file out_file : text;
        variable l_out : line;
        variable status : file_open_status;
        variable sample_count : integer := 0;
    begin
        file_open(status, out_file, "sim_data/vhdl_lagrange.txt", write_mode);
        if status /= open_ok then
            file_open(status, out_file, "../../sim_data/vhdl_lagrange.txt", write_mode);
        end if;
        assert status = open_ok report "Failed to open sim_data/vhdl_lagrange.txt for writing" severity failure;

        while sample_count < EXPECTED_OUTPUTS loop
            wait until rising_edge(clk);
            if out_valid = '1' then
                write(l_out, to_integer(out_i));
                write(l_out, ' ');
                write(l_out, to_integer(out_q));
                writeline(out_file, l_out);
                sample_count := sample_count + 1;
            end if;
        end loop;

        file_close(out_file);
        report "Lagrange streaming simulation completed successfully! Captured " & integer'image(sample_count) & " samples." severity note;
        sim_finished <= true;
        wait;
    end process;

end architecture sim;
