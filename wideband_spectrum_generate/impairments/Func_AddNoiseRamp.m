function x = Func_AddNoiseRamp(x, fs, Noise_Amp)

    N = length(x);

    % 全局缓慢噪声底变化，幅度较温和
    if rand < 0.5
        g1_dB = -3 + 3 * rand;      % [-3, 0] dB
        g2_dB = 3 + 9 * rand;       % [3, 12] dB
    else
        g1_dB = 3 + 9 * rand;       % [3, 12] dB
        g2_dB = -3 + 3 * rand;      % [-3, 0] dB
    end

    gain_dB = linspace(g1_dB, g2_dB, N);
    gain = 10.^(gain_dB / 20);

    noise = Noise_Amp * gain .* randn(1, N);

    x = x + noise;
end