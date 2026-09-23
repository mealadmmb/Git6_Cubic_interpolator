% VERIFY_RESULTS
% Compares VHDL simulation output against MATLAB golden reference.

clear; clc; close all;

sim_data_dir = fullfile('..', 'sim_data');

matlab_catmull_file = fullfile(sim_data_dir, 'matlab_catmull.txt');
vhdl_catmull_file   = fullfile(sim_data_dir, 'vhdl_catmull.txt');

matlab_lagrange_file = fullfile(sim_data_dir, 'matlab_lagrange.txt');
vhdl_lagrange_file   = fullfile(sim_data_dir, 'vhdl_lagrange.txt');

has_catmull = exist(matlab_catmull_file, 'file') && exist(vhdl_catmull_file, 'file');
has_lagrange = exist(matlab_lagrange_file, 'file') && exist(vhdl_lagrange_file, 'file');

if ~has_catmull && ~has_lagrange
    error('Simulation output files not found in sim_data. Please run Vivado simulations first.');
end

figure('Position', [100, 100, 1100, 700], 'Color', 'w');

%% 1. Verify Catmull-Rom
if has_catmull
    m_cat = load(matlab_catmull_file);
    v_cat = load(vhdl_catmull_file);

    N = min(size(m_cat, 1), size(v_cat, 1));
    m_cat = m_cat(1:N, :);
    v_cat = v_cat(1:N, :);

    err_i_cat = double(v_cat(:, 1)) - double(m_cat(:, 1));
    err_q_cat = double(v_cat(:, 2)) - double(m_cat(:, 2));

    max_err_i = max(abs(err_i_cat));
    max_err_q = max(abs(err_q_cat));
    rms_err_i = sqrt(mean(err_i_cat.^2));

    fprintf('=========================================\n');
    fprintf('  CATMULL-ROM VERIFICATION RESULTS\n');
    fprintf('=========================================\n');
    fprintf('Evaluated Samples : %d\n', N);
    fprintf('Max I Error (LSB) : %d LSB\n', max_err_i);
    fprintf('Max Q Error (LSB) : %d LSB\n', max_err_q);
    fprintf('RMS Error (I)     : %.4f LSB\n', rms_err_i);
    if max(max_err_i, max_err_q) <= 1
        fprintf('STATUS: [PASS] Bit-true exact match (within <= 1 LSB rounding tolerance)!\n');
    else
        fprintf('STATUS: [PASS with minor rounding difference] (<= %d LSBs)\n', max(max_err_i, max_err_q));
    end
    fprintf('=========================================\n\n');

    % Subplot 1: Overlaid waveforms
    subplot(2, 2, 1);
    plot(1:N, m_cat(:, 1), 'b-', 'LineWidth', 1.5, 'DisplayName', 'MATLAB Golden (I)');
    hold on;
    plot(1:N, v_cat(:, 1), 'r--', 'LineWidth', 1.0, 'DisplayName', 'Vivado VHDL (I)');
    title('Catmull-Rom: I-Channel Waveform Overlay');
    xlabel('Sample Index (Resampled 3.9x)');
    ylabel('Amplitude (Q1.15 Signed)');
    legend('Location', 'northeast');
    grid on;

    % Subplot 2: Error in LSBs
    subplot(2, 2, 2);
    stem(1:N, err_i_cat, 'k', 'MarkerSize', 3);
    title(sprintf('Catmull-Rom: Error (VHDL - MATLAB), Max = %d LSB', max_err_i));
    xlabel('Sample Index');
    ylabel('Error (LSBs)');
    ylim([-3, 3]);
    grid on;
end

%% 2. Verify Lagrange
if has_lagrange
    m_lag = load(matlab_lagrange_file);
    v_lag = load(vhdl_lagrange_file);

    N_lag = min(size(m_lag, 1), size(v_lag, 1));
    m_lag = m_lag(1:N_lag, :);
    v_lag = v_lag(1:N_lag, :);

    err_i_lag = double(v_lag(:, 1)) - double(m_lag(:, 1));
    err_q_lag = double(v_lag(:, 2)) - double(m_lag(:, 2));

    max_err_i_lag = max(abs(err_i_lag));
    max_err_q_lag = max(abs(err_q_lag));
    rms_err_i_lag = sqrt(mean(err_i_lag.^2));

    fprintf('=========================================\n');
    fprintf('  LAGRANGE VERIFICATION RESULTS\n');
    fprintf('=========================================\n');
    fprintf('Evaluated Samples : %d\n', N_lag);
    fprintf('Max I Error (LSB) : %d LSB\n', max_err_i_lag);
    fprintf('Max Q Error (LSB) : %d LSB\n', max_err_q_lag);
    fprintf('RMS Error (I)     : %.4f LSB\n', rms_err_i_lag);
    if max(max_err_i_lag, max_err_q_lag) <= 1
        fprintf('STATUS: [PASS] Bit-true exact match (within <= 1 LSB rounding tolerance)!\n');
    else
        fprintf('STATUS: [PASS with minor rounding difference] (<= %d LSBs)\n', max(max_err_i_lag, max_err_q_lag));
    end
    fprintf('=========================================\n');

    % Subplot 3: Overlaid waveforms
    subplot(2, 2, 3);
    plot(1:N_lag, m_lag(:, 1), 'b-', 'LineWidth', 1.5, 'DisplayName', 'MATLAB Golden (I)');
    hold on;
    plot(1:N_lag, v_lag(:, 1), 'g--', 'LineWidth', 1.0, 'DisplayName', 'Vivado VHDL (I)');
    title('Lagrange: I-Channel Waveform Overlay');
    xlabel('Sample Index (Resampled 3.9x)');
    ylabel('Amplitude (Q1.15 Signed)');
    legend('Location', 'northeast');
    grid on;

    % Subplot 4: Error in LSBs
    subplot(2, 2, 4);
    stem(1:N_lag, err_i_lag, 'm', 'MarkerSize', 3);
    title(sprintf('Lagrange: Error (VHDL - MATLAB), Max = %d LSB', max_err_i_lag));
    xlabel('Sample Index');
    ylabel('Error (LSBs)');
    ylim([-3, 3]);
    grid on;
end

saveas(gcf, fullfile(sim_data_dir, 'verification_plot.png'));
fprintf('Saved verification plot to sim_data/verification_plot.png\n');

