function x = Func_AddTimeVaryingNoiseFloor(x, fs, Noise_Amp)

    N = length(x);

    % 控制点数量，越少变化越慢
    CtrlNum = randi([4, 10]);

    ctrl_t = linspace(1, N, CtrlNum);

    % 噪声底变化范围，单位 dB
    ctrl_gain_dB = -5 + 15 * rand(1, CtrlNum);  % [-6, 6] dB

    gain_dB = interp1(ctrl_t, ctrl_gain_dB, 1:N, 'pchip');
    gain = 10.^(gain_dB / 20);

    noise = randn(1, N) .* gain * Noise_Amp;

    x = x + noise;
end