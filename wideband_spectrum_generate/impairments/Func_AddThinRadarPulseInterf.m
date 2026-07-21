function [x, RadarPulseBlocks] = Func_AddThinRadarPulseInterf(x, fs, Noise_Amp)
% 极短时宽带脉冲干扰
% 时频图表现：很细的横向亮线

    N = length(x);
    RadarPulseBlocks = [];

    % 脉冲条数
    NumPulse = randi([3, 15]);

    for k = 1:NumPulse

        % 持续时间，单位 ms
        % 0.02~0.20 ms，非常短
        Dur_ms = 0.02 + rand * 0.18;

        Dur = max(2, round(Dur_ms * fs));
        Dur = min(Dur, N-1);

        Beg = randi([1, N-Dur]);
        Endd = Beg + Dur - 1;

        % 强度，比底噪高 15~35 dB
        Pulse_dB = 15 + 20 * rand;
        PulseAmp = Noise_Amp * 10^(Pulse_dB/20);

        % 宽带噪声脉冲
        Pulse = randn(1, Dur) * PulseAmp;

        % 加窗，避免过硬边缘
        if Dur >= 4
            Win = hann(Dur).';
            Pulse = Pulse .* Win;
        end

        x(Beg:Endd) = x(Beg:Endd) + Pulse;

        RadarPulseBlocks = [RadarPulseBlocks; Beg/fs, Endd/fs];
    end
end