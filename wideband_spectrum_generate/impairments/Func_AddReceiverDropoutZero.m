function [x, DropoutBlocks] = Func_AddReceiverDropoutZero(x, fs)
% 模拟接收机丢数/采集中断：某些时间段采样值被置零
%
% 输入：
%   x  : 宽带时域信号
%   fs : kHz。当前主程序中 fs=6400，1 ms 对应 fs 个采样点
%
% 输出：
%   x             : 加入置零丢数后的信号
%   DropoutBlocks : 丢数时间段，单位 ms，格式为 [tbeg_ms, tend_ms]

    N = length(x);

    BlockNum = randi([1, 3]);
    DropoutBlocks = zeros(BlockNum, 2);

    for k = 1:BlockNum

        % 建议先用 1~16 ms，太长会大量切碎标签
        dur_ms = 1 + 15 * rand;
        dur_len = round(dur_ms * fs);

        if dur_len < 1
            dur_len = 1;
        end

        if dur_len >= N
            dur_len = floor(N * 0.1);
        end

        beg_idx = randi([1, N - dur_len + 1]);
        end_idx = beg_idx + dur_len - 1;

        x(beg_idx:end_idx) = 0;

        % 转换为 ms
        tbeg_ms = (beg_idx - 1) / fs;
        tend_ms = end_idx / fs;

        DropoutBlocks(k, :) = [tbeg_ms, tend_ms];
    end

    DropoutBlocks = MergeTimeBlocks(DropoutBlocks);
end