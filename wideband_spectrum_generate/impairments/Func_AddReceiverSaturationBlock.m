function [x, SaturationBlocks] = Func_AddReceiverSaturationBlock(x, fs, Noise_Amp)
% 模拟接收机短时饱和/前端过载，形成整条时频图强白横带
%
% 输入：
%   x         : 输入宽带实信号
%   fs        : kHz，fs=6400 时，1 ms 对应 fs 个采样点
%   Noise_Amp : 原始噪声幅度
%
% 输出：
%   x                : 加入饱和块后的信号
%   SaturationBlocks : 饱和遮挡时间段，单位 ms，格式 [tbeg_ms, tend_ms]
%
% 说明：
%   这里把饱和段视为“不可见遮挡区”，后续标签应像 DropoutBlocks 一样扣除。

    N = length(x);

    BlockNum = randi([1, 3]);
    SaturationBlocks = zeros(BlockNum, 2);

    for k = 1:BlockNum

        % 饱和持续时间，单位 ms
        dur_ms = 5 + 35 * rand;       % 5~40 ms
        dur_len = round(dur_ms * fs);

        if dur_len < 1
            dur_len = 1;
        end

        if dur_len >= N
            dur_len = floor(N * 0.1);
        end

        beg_idx = randi([1, N - dur_len + 1]);
        end_idx = beg_idx + dur_len - 1;

        % 强制重度饱和：比原始噪声高很多
        % 建议 35~55 dB，基本能保证图上变成白色横带
        rise_dB = 35 + 20 * rand;     % 35~55 dB

        sat_noise_amp = Noise_Amp * 10^(rise_dB / 20);

        % 用强宽带噪声替换该时间段，而不是简单相加
        % 替换比相加更像“前端过载后原信号不可辨认”
        sat_noise = sat_noise_amp * randn(1, dur_len);

        x(beg_idx:end_idx) = sat_noise;

        % 再做限幅，形成饱和平台效果
        % 注意：这里不是把时域置 1，而是把该段压成强饱和波形
        clip_th = sat_noise_amp * (0.20 + 0.20 * rand);   % 0.20~0.40
        x(beg_idx:end_idx) = max(min(x(beg_idx:end_idx), clip_th), -clip_th);

        % 记录饱和时间段，单位 ms
        tbeg_ms = (beg_idx - 1) / fs;
        tend_ms = end_idx / fs;

        SaturationBlocks(k, :) = [tbeg_ms, tend_ms];
    end

    SaturationBlocks = MergeTimeBlocks(SaturationBlocks);
end