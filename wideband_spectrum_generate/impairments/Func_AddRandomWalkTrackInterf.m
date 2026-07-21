function [SignalNoiseOut, TrackInfo] = Func_AddRandomWalkTrackInterf(SignalNoise, fs, Noise_Amp, Param)
% Func_AddRandomWalkTrackInterf
% 在宽带时域信号中加入随机游走轨迹线干扰
%
% 输入：
%   SignalNoise : 原始宽带时域信号
%   fs          : 采样率，单位 kHz。你的代码中 fs = 6400，表示 6400 ksample/s? 按现有代码理解为 samples/ms
%   Noise_Amp   : 噪声幅度，用于控制干扰强度
%   Param       : 参数结构体，可省略
%
% 输出：
%   SignalNoiseOut : 加入轨迹干扰后的信号
%   TrackInfo      : 轨迹信息，仅用于调试，不写 XML

    if nargin < 4
        Param = struct();
    end

    % ============================================================
    % 1. 默认参数
    % ============================================================

    if ~isfield(Param, 'TrackNumRange')
        Param.TrackNumRange = [1, 3];          % 每张图轨迹数量
    end

    if ~isfield(Param, 'DurRangeMs')
        Param.DurRangeMs = [30, 160];          % 每条轨迹持续时间，ms
    end

    if ~isfield(Param, 'FreqRangeKHz')
        Param.FreqRangeKHz = [100, fs/2-100];  % 轨迹频率范围，kHz
    end

    if ~isfield(Param, 'AmpRange')
        Param.AmpRange = [1.0, 5.0];           % 干扰幅度 = AmpRange * Noise_Amp
    end

    if ~isfield(Param, 'MaxVelKHzPerMs')
        Param.MaxVelKHzPerMs = 20;             % 最大频率速度，kHz/ms
    end

    if ~isfield(Param, 'MaxAccKHzPerMs2')
        Param.MaxAccKHzPerMs2 = 12;            % 最大频率加速度，kHz/ms^2
    end

    if ~isfield(Param, 'CtrlDtMs')
        Param.CtrlDtMs = 0.2;                  % 轨迹控制点时间间隔，ms
    end

    if ~isfield(Param, 'ToneNumRange')
        Param.ToneNumRange = [1, 3];           % 每条轨迹由几根近邻细线组成
    end

    if ~isfield(Param, 'ToneSpreadKHz')
        Param.ToneSpreadKHz = 3.0;             % 近邻细线频率扩展，kHz
    end

    if ~isfield(Param, 'FadeRatio')
        Param.FadeRatio = 0.10;                % 起止淡入淡出比例
    end

    if ~isfield(Param, 'AmpJitterDepth')
        Param.AmpJitterDepth = 0.35;           % 幅度抖动深度，0~1
    end

    if ~isfield(Param, 'AmpJitterCtrlDtMs')
        Param.AmpJitterCtrlDtMs = 2.0;         % 幅度抖动控制间隔，ms
    end

    % ============================================================
    % 2. 初始化
    % ============================================================

    SignalNoiseOut = SignalNoise;

    DataLen = length(SignalNoise);
    TotalTimeMs = DataLen / fs;

    TrackNum = randi(Param.TrackNumRange);

    TrackInfo = struct();
    TrackInfo.TrackNum = TrackNum;
    TrackInfo.Track = cell(1, TrackNum);

    % ============================================================
    % 3. 逐条生成随机轨迹干扰
    % ============================================================

    for TrIdx = 1:TrackNum

        % --------------------------------------------------------
        % 3.1 随机决定轨迹起止时间
        % --------------------------------------------------------

        CurDurMs = Param.DurRangeMs(1) + ...
            rand * (Param.DurRangeMs(2) - Param.DurRangeMs(1));

        CurDurMs = min(CurDurMs, TotalTimeMs);

        CurBegMs = rand * max(TotalTimeMs - CurDurMs, 0);
        CurEndMs = CurBegMs + CurDurMs;

        BegIdx = max(1, floor(CurBegMs * fs) + 1);
        EndIdx = min(DataLen, floor(CurEndMs * fs));

        if EndIdx <= BegIdx
            continue;
        end

        N = EndIdx - BegIdx + 1;
        tMs = (0:N-1) / fs;

        % --------------------------------------------------------
        % 3.2 生成随机游走频率轨迹 f(t)
        % --------------------------------------------------------

        CtrlDtMs = Param.CtrlDtMs;
        CtrlNum = max(3, ceil(CurDurMs / CtrlDtMs));

        fMin = Param.FreqRangeKHz(1);
        fMax = Param.FreqRangeKHz(2);

        fCtrl = zeros(1, CtrlNum);
        vCtrl = zeros(1, CtrlNum);

        fCtrl(1) = fMin + rand * (fMax - fMin);
        vCtrl(1) = (2*rand - 1) * Param.MaxVelKHzPerMs;

        for k = 2:CtrlNum

            % 随机加速度
            acc = (2*rand - 1) * Param.MaxAccKHzPerMs2;

            % 更新速度
            vCtrl(k) = vCtrl(k-1) + acc * CtrlDtMs;

            % 限制最大速度
            vCtrl(k) = min(max(vCtrl(k), ...
                -Param.MaxVelKHzPerMs), Param.MaxVelKHzPerMs);

            % 更新频率
            fCtrl(k) = fCtrl(k-1) + vCtrl(k) * CtrlDtMs;

            % 边界反弹，防止跑出频率范围
            if fCtrl(k) < fMin
                fCtrl(k) = fMin + (fMin - fCtrl(k));
                vCtrl(k) = abs(vCtrl(k));
            elseif fCtrl(k) > fMax
                fCtrl(k) = fMax - (fCtrl(k) - fMax);
                vCtrl(k) = -abs(vCtrl(k));
            end

            % 再保险裁剪
            fCtrl(k) = min(max(fCtrl(k), fMin), fMax);
        end

        % 控制点时间
        tCtrl = linspace(0, CurDurMs, CtrlNum);

        % 插值到采样点
        fInst = interp1(tCtrl, fCtrl, tMs, 'pchip', 'extrap');

        % 再次限制频率范围
        fInst = min(max(fInst, fMin), fMax);

        % --------------------------------------------------------
        % 3.3 幅度包络：淡入淡出 + 慢速随机抖动
        % --------------------------------------------------------

        AmpBase = Noise_Amp * ...
            (Param.AmpRange(1) + rand * (Param.AmpRange(2) - Param.AmpRange(1)));

        Env = ones(1, N);

        FadeLen = round(N * Param.FadeRatio);
        FadeLen = min(FadeLen, floor(N/2));

        if FadeLen > 1
            FadeWin = 0.5 - 0.5*cos(pi*(0:FadeLen-1)/(FadeLen-1));
            Env(1:FadeLen) = Env(1:FadeLen) .* FadeWin;
            Env(end-FadeLen+1:end) = Env(end-FadeLen+1:end) .* fliplr(FadeWin);
        end

        % 幅度慢抖动，让轨迹亮度不完全均匀
        AmpCtrlDtMs = Param.AmpJitterCtrlDtMs;
        AmpCtrlNum = max(3, ceil(CurDurMs / AmpCtrlDtMs));
        AmpCtrlT = linspace(0, CurDurMs, AmpCtrlNum);

        AmpCtrl = 1 + Param.AmpJitterDepth * randn(1, AmpCtrlNum);
        AmpCtrl = max(0.1, AmpCtrl);

        AmpJitter = interp1(AmpCtrlT, AmpCtrl, tMs, 'pchip', 'extrap');
        AmpJitter = max(0.1, AmpJitter);

        Env = Env .* AmpJitter;

        % --------------------------------------------------------
        % 3.4 根据瞬时频率合成时域调频干扰
        % --------------------------------------------------------

        ToneNum = randi(Param.ToneNumRange);

        TrackSig = zeros(1, N);

        for Tn = 1:ToneNum

            % 多根很近的细线，让轨迹有一点厚度
            if ToneNum == 1
                FreqOffset = 0;
            else
                FreqOffset = (rand - 0.5) * 2 * Param.ToneSpreadKHz;
            end

            fTone = fInst + FreqOffset;
            fTone = min(max(fTone, fMin), fMax);

            % 相位积分
            Phase = 2*pi*cumsum(fTone / fs) + 2*pi*rand;

            ToneAmp = AmpBase / sqrt(ToneNum) * (0.7 + 0.6*rand);

            TrackSig = TrackSig + ToneAmp * Env .* cos(Phase);
        end

        % --------------------------------------------------------
        % 3.5 加入原始信号
        % --------------------------------------------------------

        SignalNoiseOut(BegIdx:EndIdx) = SignalNoiseOut(BegIdx:EndIdx) + TrackSig;

        % --------------------------------------------------------
        % 3.6 记录调试信息
        % --------------------------------------------------------

        CurInfo = struct();
        CurInfo.TBegMs = CurBegMs;
        CurInfo.TEndMs = CurEndMs;
        CurInfo.FreqCtrlKHz = fCtrl;
        CurInfo.TimeCtrlMs = tCtrl;
        CurInfo.AmpBase = AmpBase;
        CurInfo.ToneNum = ToneNum;

        TrackInfo.Track{TrIdx} = CurInfo;
    end
end