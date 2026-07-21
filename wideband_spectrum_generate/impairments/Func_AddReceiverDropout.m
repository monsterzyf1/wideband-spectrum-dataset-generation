function x = Func_AddReceiverDropout(x, fs)
% 模拟接收机丢数/采集中断/DMA丢包
% 三种模式：
% 1) 置零
% 2) 强衰减
% 3) 保持上一采样值

    N = length(x);

    BlockNum = randi([1, 3]);

    for k = 1:BlockNum

        dur_ms = 1 + 20 * rand;       % 1~21 ms
        dur_len = round(dur_ms * fs);

        if dur_len >= N
            continue;
        end

        beg_idx = randi([2, N - dur_len + 1]);
        end_idx = beg_idx + dur_len - 1;

        mode = rand;

        if mode < 1
            % 模式1：补零，时频图明显变黑
            x(beg_idx:end_idx) = 0;

%         elseif mode < 0.90
%             % 模式2：强衰减，较自然的暗带
%             atten_dB = 25 + 35 * rand;    % 25~60 dB
%             atten = 10^(-atten_dB / 20);
%             x(beg_idx:end_idx) = x(beg_idx:end_idx) * atten;

        else
            % 模式3：保持上一值，模拟采样冻结/缓存异常
            x(beg_idx:end_idx) = x(beg_idx - 1);
        end
    end
end