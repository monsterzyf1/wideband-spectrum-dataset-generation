function x = Func_AddSegmentNoiseRise(x, fs, Noise_Amp)

    N = length(x);

    SegNum = randi([1, 4]);

    for k = 1:SegNum

        seg_len_ms = 1 + 40 * rand;          % 5~45 ms
        seg_len = round(seg_len_ms * fs);

        if seg_len >= N
            continue;
        end

        beg_idx = randi([1, N - seg_len + 1]);
        end_idx = beg_idx + seg_len - 1;

        rise_dB = 6 + 18 * rand;             % 噪声增强 6~24 dB
        amp = Noise_Amp * 10^(rise_dB / 20);

        x(beg_idx:end_idx) = x(beg_idx:end_idx) + ...
            amp * randn(1, seg_len);
    end
end