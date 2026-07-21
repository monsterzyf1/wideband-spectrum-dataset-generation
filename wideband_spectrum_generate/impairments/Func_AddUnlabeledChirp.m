function x = Func_AddUnlabeledChirp(x, fs, BaseNoiseAmp)
    DataLen = length(x);
    T = DataLen / fs;

    % 避开频谱边缘
    f_margin = 60;
    
%     % 持续时间更长，保证时频图上能看见斜线
%     dur = T * (0.15 + 0.35*rand);   % 30~100 ms
% 
%     % 扫频范围不要太大，否则太陡
%     sweep_bw = 200 + 600*rand;      % kHz
% 
%     f_start = f_margin + rand * (fs/2 - 2*f_margin - sweep_bw);
% 
%     if rand < 0.5
%         f_end = f_start + sweep_bw;
%     else
%         f_end = f_start - sweep_bw;
%     end
% 
%     f_end = min(max(f_end, f_margin), fs/2 - f_margin);
    
    f_start = f_margin + rand * (fs/2 - 2*f_margin);
    f_end   = f_margin + rand * (fs/2 - 2*f_margin);

    % 干扰强度：不要总是太强
    amp = BaseNoiseAmp * (0.5 + 2.5*rand);

    % 持续时间：短、中、长混合
    p = rand;
    if p < 0.5
        dur = T * (0.005 + 0.03*rand);
    elseif p < 0.85
        dur = T * (0.03 + 0.12*rand);
    else
        dur = T * (0.15 + 0.25*rand);
    end

    t0 = rand * max(T - dur, 0);
    idx1 = max(1, round(t0 * fs) + 1);
    idx2 = min(DataLen, round((t0 + dur) * fs));

    L = idx2 - idx1 + 1;
    if L <= 8
        return;
    end

    tt = (0:L-1) / fs;
    k = (f_end - f_start) / max(dur, 1e-6);

    phase = 2*pi*(f_start*tt + 0.5*k*tt.^2);

    % 轻微频率抖动，避免过于理想
    if rand < 0.5
        freq_jitter = cumsum(randn(1, L));
        freq_jitter = freq_jitter / (max(abs(freq_jitter)) + eps) * (5 + 30*rand);
        phase = phase + 2*pi*cumsum(freq_jitter) / fs;
    end

    % 开关包络，避免硬切换
    env = ones(1, L);
    ramp_len = min(round(0.05 * L), round(0.2 * fs));
    ramp_len = min(ramp_len, floor(L/4));

    if ramp_len > 2
        ramp = 0.5 - 0.5*cos(pi*(0:ramp_len-1)/(ramp_len-1));
        env(1:ramp_len) = ramp;
        env(end-ramp_len+1:end) = fliplr(ramp);
    end

    chirp_seg = amp * cos(phase) .* env;

    x(idx1:idx2) = x(idx1:idx2) + chirp_seg;
end