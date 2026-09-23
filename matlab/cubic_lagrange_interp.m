function y_out = cubic_lagrange_interp(ym1, y0, y1, y2, mu_u16)
% CUBIC_LAGRANGE_INTERP Bit-true fixed-point (Q1.15) Lagrange 4-point cubic interpolator.
%
% Inputs:
%   ym1, y0, y1, y2 : int16 signed samples in Q1.15 format [-32768, 32767]
%   mu_u16          : uint16 fractional phase in Q0.16 format [0, 65535]
%
% Output:
%   y_out           : int16 interpolated sample in Q1.15 format

    ym1_d = double(ym1);
    y0_d  = double(y0);
    y1_d  = double(y1);
    y2_d  = double(y2);
    mu_d  = double(mu_u16);

    % Exact integer coefficients (scaled by 6):
    % 6*a0 = 6*y0
    % 6*a1 = -2*ym1 - 3*y0 + 6*y1 - y2
    % 6*a2 = 3*ym1 - 6*y0 + 3*y1
    % 6*a3 = -ym1 + 3*y0 - 3*y1 + y2
    c0 = 6 * y0_d;
    c1 = -2 * ym1_d - 3 * y0_d + 6 * y1_d - y2_d;
    c2 = 3 * ym1_d - 6 * y0_d + 3 * y1_d;
    c3 = -ym1_d + 3 * y0_d - 3 * y1_d + y2_d;

    % Horner evaluation with Q0.16 multiplier and symmetric rounding:
    % T1 = (c3 * mu + 32768) >> 16 + c2
    prod1 = c3 * mu_d;
    t1 = floor((prod1 + 32768) / 65536) + c2;

    % T2 = (T1 * mu + 32768) >> 16 + c1
    prod2 = t1 * mu_d;
    t2 = floor((prod2 + 32768) / 65536) + c1;

    % T3 = (T2 * mu + 32768) >> 16 + c0
    prod3 = t2 * mu_d;
    t3 = floor((prod3 + 32768) / 65536) + c0;

    % Division by 6 using fixed-point reciprocal K = round(2^16 / 6) = 10923:
    % y_scaled = (t3 * 10923 + 32768) >> 16
    y_scaled = floor((t3 * 10923 + 32768) / 65536);

    % Saturation to 16-bit signed range [-32768, 32767]
    y_sat = max(-32768, min(32767, y_scaled));
    y_out = int16(y_sat);
end

