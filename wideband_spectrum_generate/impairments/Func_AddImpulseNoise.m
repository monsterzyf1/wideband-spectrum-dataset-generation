function x = Func_AddImpulseNoise(x, fs, BaseNoiseAmp)

    DataLen = length(x);

    % 脉冲个数
    NumPulse = randi([1, 5]);

    for k = 1:NumPulse

        % 脉冲持续时间：0.02~0.3 ms
%         dur_ms = 0.02 + 0.28*rand;
        dur_ms = 0.005 + 0.045*rand;
        L = max(2, round(dur_ms * fs));

        idx1 = randi([1, max(1, DataLen-L+1)]);
        idx2 = min(DataLen, idx1+L-1);

        L = idx2 - idx1 + 1;

        % 幅度：短时强干扰
        amp = BaseNoiseAmp * (3 + 12*rand);
        amp = BaseNoiseAmp * (10 + 15*rand);

        % 包络，避免完全硬切
        env = hann(L).';

        pulse = amp * randn(1, L) .* env;

        x(idx1:idx2) = x(idx1:idx2) + pulse;
    end
end