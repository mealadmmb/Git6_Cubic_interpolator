% GENERATE_STIMULUS
% Generates dual-channel (I/Q) stimulus and golden reference for 3.9x cubic interpolation.

clear; clc;

% Create directories if not exist
sim_data_dir = fullfile('..', 'sim_data');
if ~exist(sim_data_dir, 'dir')
    mkdir(sim_data_dir);
end

% 1. Generate Input Test Signal (Complex I/Q)
% We use a composite dual-tone signal with AM modulation to test varying slopes and curvatures.
N_in = 200;
n = (0:N_in-1)';

f1 = 0.035; % Normalized frequency 1
f2 = 0.085; % Normalized frequency 2

% Complex envelope with dynamic range within [-0.85, +0.85] to leave headroom for overshoot
envelope = 0.75 + 0.15 * cos(2 * pi * 0.01 * n);
i_cont = envelope .* (0.6 * cos(2 * pi * f1 * n) + 0.4 * cos(2 * pi * f2 * n + 0.2));
q_cont = envelope .* (0.6 * sin(2 * pi * f1 * n) + 0.4 * sin(2 * pi * f2 * n + 0.5));

% Quantize to 16-bit signed Q1.15
scale_factor = 32767;
i_in_q15 = int16(round(i_cont * scale_factor));
q_in_q15 = int16(round(q_cont * scale_factor));

% 2. Resampling Parameters (3.9x upsampling)
R = 3.9;
% Step size = round(2^32 / 3.9) = 1101273666 (0x41A41A42)
step_32 = uint64(hex2dec('41A41A42'));

out_i_catmull  = [];
out_q_catmull  = [];
out_i_lagrange = [];
out_q_lagrange = [];

% Run exact bit-true 32-bit Phase Accumulator (NCO)
phase_acc = uint64(0);
rd_k = 1;

while rd_k <= 197
    mu_u16 = uint16(bitshift(bitand(phase_acc, uint64(hex2dec('FFFF0000'))), -16));

    % 4 input samples: y(k-1), y(k), y(k+1), y(k+2)
    idx_m1 = rd_k;
    idx_0  = rd_k + 1;
    idx_1  = rd_k + 2;
    idx_2  = rd_k + 3;

    % In-phase (I) channel
    ym1_i = i_in_q15(idx_m1);
    y0_i  = i_in_q15(idx_0);
    y1_i  = i_in_q15(idx_1);
    y2_i  = i_in_q15(idx_2);

    % Quadrature (Q) channel
    ym1_q = q_in_q15(idx_m1);
    y0_q  = q_in_q15(idx_0);
    y1_q  = q_in_q15(idx_1);
    y2_q  = q_in_q15(idx_2);

    % Catmull-Rom
    out_i_catmull(end+1, 1) = cubic_catmull_interp(ym1_i, y0_i, y1_i, y2_i, mu_u16);
    out_q_catmull(end+1, 1) = cubic_catmull_interp(ym1_q, y0_q, y1_q, y2_q, mu_u16);

    % Lagrange
    out_i_lagrange(end+1, 1) = cubic_lagrange_interp(ym1_i, y0_i, y1_i, y2_i, mu_u16);
    out_q_lagrange(end+1, 1) = cubic_lagrange_interp(ym1_q, y0_q, y1_q, y2_q, mu_u16);

    % Advance 32-bit Phase Accumulator
    next_phase = phase_acc + step_32;
    if next_phase >= 2^32
        rd_k = rd_k + 1;
        phase_acc = bitand(next_phase, uint64(2^32 - 1));
    else
        phase_acc = next_phase;
    end
end

k_start = 1;
k_end = 197;
N_out = length(out_i_catmull);
fprintf('Generated %d input samples, %d resampled output samples (Rate ratio = %.4f)\n', ...
    N_in, N_out, N_out / (k_end - k_start));

% 3. Export to text files for VHDL Testbenches
% File 1: input_iq.txt (format: I Q)
fid = fopen(fullfile(sim_data_dir, 'input_iq.txt'), 'w');
for idx = 1:N_in
    fprintf(fid, '%d %d\n', i_in_q15(idx), q_in_q15(idx));
end
fclose(fid);

% File 2: matlab_catmull.txt (format: I Q)
fid = fopen(fullfile(sim_data_dir, 'matlab_catmull.txt'), 'w');
for idx = 1:N_out
    fprintf(fid, '%d %d\n', out_i_catmull(idx), out_q_catmull(idx));
end
fclose(fid);

% File 3: matlab_lagrange.txt (format: I Q)
fid = fopen(fullfile(sim_data_dir, 'matlab_lagrange.txt'), 'w');
for idx = 1:N_out
    fprintf(fid, '%d %d\n', out_i_lagrange(idx), out_q_lagrange(idx));
end
fclose(fid);

% Save metadata
save(fullfile(sim_data_dir, 'stimulus_meta.mat'), 'N_in', 'N_out', 'R', 'step_32', 'k_start', 'k_end');
fprintf('Successfully exported stimulus and golden reference data to sim_data/\n');
