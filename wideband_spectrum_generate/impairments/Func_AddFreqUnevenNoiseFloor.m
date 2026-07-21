function [SignalNoiseOut, FreqRespInfo] = Func_AddFreqUnevenNoiseFloor(SignalNoise, fs, Param)
% Func_AddFreqUnevenNoiseFloor
% 模拟频域底噪不平坦 / 宽带接收机频率响应起伏
%
% 输入：
%   SignalNoise : 原始时域宽带信号
%   fs          : 采样率，单位 kHz。你的代码中 fs = 6400
%   Param       : 参数结构体，可省略
%
% 输出：
%   SignalNoiseOut : 加入频域不平坦损伤后的时域信号
%   FreqRespInfo   : 频响信息，仅用于调试，不写 XML
%
% 说明：
%   这个函数不会新增标签。
%   它是对整个 SignalNoise 施加随机幅频响应，
%   因此真实信号和噪声都会受到频率响应不平坦的影响。

    if nargin < 3
        Param = struct();
    end

    % ============================================================
    % 1. 默认参数
    % ============================================================

    if ~isfield(Param, 'MaxRippledB')
        Param.MaxRippledB = 6;              % 平滑随机起伏最大幅度，dB
    end

    if ~isfield(Param, 'TiltRangeDB')
        Param.TiltRangeDB = [-4, 4];        % 频率方向整体倾斜范围，dB
    end

    if ~isfield(Param, 'BumpNumRange')
        Param.BumpNumRange = [1, 4];        % 局部隆起 / 凹陷数量
    end

    if ~isfield(Param, 'BumpAmpRangeDB')
        Param.BumpAmpRangeDB = [-6, 8];     % 局部隆起 / 凹陷幅度，dB
    end

    if ~isfield(Param, 'BumpWidthRangeKHz')
        Param.BumpWidthRangeKHz = [80, 500]; % 局部隆起 / 凹陷宽度，kHz
    end

    if ~isfield(Param, 'SmoothCtrlNum')
        Param.SmoothCtrlNum = 12;           % 平滑起伏控制点数量
    end

    if ~isfield(Param, 'KeepRMS')
        Param.KeepRMS = true;               % 是否保持处理前后 RMS 基本一致
    end

    if ~isfield(Param, 'MaxTotalGaindB')
        Param.MaxTotalGaindB = 12;          % 最终频响最大限制，dB
    end

    % ============================================================
    % 2. 初始化
    % ============================================================

    SignalNoise = double(SignalNoise);
    DataLen = length(SignalNoise);

    % 为了构造双边频响，使用完整 FFT
    X = fft(SignalNoise);

    % 频率轴，单位 kHz，范围大致为 -fs/2 到 fs/2
    FreqAxis = ((0:DataLen-1) / DataLen) * fs;
    FreqAxis(FreqAxis > fs/2) = FreqAxis(FreqAxis > fs/2) - fs;

    AbsFreqAxis = abs(FreqAxis);            % 只看频率绝对值
    FreqNorm = AbsFreqAxis / (fs/2);        % 归一化到 0~1

    % 这里只设计关于 0 Hz 对称的频响，保证时域结果仍然是实数
    H_dB = zeros(1, DataLen);

    % ============================================================
    % 3. 整体频率倾斜
    % ============================================================

    TiltDB = Param.TiltRangeDB(1) + ...
        rand * (Param.TiltRangeDB(2) - Param.TiltRangeDB(1));

    % 低频到高频线性倾斜
    TiltShape = (FreqNorm - 0.5) * 2;
    H_dB = H_dB + TiltDB * TiltShape;

    % ============================================================
    % 4. 平滑随机起伏
    % ============================================================

    CtrlNum = Param.SmoothCtrlNum;

    CtrlFreq = linspace(0, fs/2, CtrlNum);
    CtrlGain = randn(1, CtrlNum);

    % 归一化控制点，避免过大
    CtrlGain = CtrlGain - mean(CtrlGain);
    CtrlGain = CtrlGain / (std(CtrlGain) + eps);

    CtrlGain = CtrlGain * Param.MaxRippledB / 2;

    SmoothRipple = interp1(CtrlFreq, CtrlGain, AbsFreqAxis, 'pchip', 'extrap');

    H_dB = H_dB + SmoothRipple;

    % ============================================================
    % 5. 局部频段隆起 / 凹陷
    % ============================================================

    BumpNum = randi(Param.BumpNumRange);

    BumpInfo = zeros(BumpNum, 3);
    % 每行：[中心频率 kHz, 宽度 kHz, 幅度 dB]

    for Bn = 1:BumpNum

        CenterFreq = rand * (fs/2);
        WidthKHz = Param.BumpWidthRangeKHz(1) + ...
            rand * (Param.BumpWidthRangeKHz(2) - Param.BumpWidthRangeKHz(1));

        AmpDB = Param.BumpAmpRangeDB(1) + ...
            rand * (Param.BumpAmpRangeDB(2) - Param.BumpAmpRangeDB(1));

        % 高斯形状频段起伏
        BumpShape = exp(-0.5 * ((AbsFreqAxis - CenterFreq) / WidthKHz).^2);

        H_dB = H_dB + AmpDB * BumpShape;

        BumpInfo(Bn, :) = [CenterFreq, WidthKHz, AmpDB];
    end

    % ============================================================
    % 6. 限制最大频响起伏，避免过强
    % ============================================================

    H_dB = H_dB - mean(H_dB);

    H_dB = min(max(H_dB, -Param.MaxTotalGaindB), Param.MaxTotalGaindB);

    % 幅度响应，注意这里是 /20
    H_amp = 10.^(H_dB / 20);

    % ============================================================
    % 7. 施加频响并回到时域
    % ============================================================

    Y = X .* H_amp;

    SignalNoiseOut = real(ifft(Y));

    % 是否保持整体 RMS 不变
    if Param.KeepRMS
        RmsIn = sqrt(mean(SignalNoise.^2) + eps);
        RmsOut = sqrt(mean(SignalNoiseOut.^2) + eps);
        SignalNoiseOut = SignalNoiseOut / RmsOut * RmsIn;
    end

    % ============================================================
    % 8. 输出调试信息
    % ============================================================

    FreqRespInfo = struct();
    FreqRespInfo.FreqAxisKHz = FreqAxis;
    FreqRespInfo.AbsFreqAxisKHz = AbsFreqAxis;
    FreqRespInfo.H_dB = H_dB;
    FreqRespInfo.TiltDB = TiltDB;
    FreqRespInfo.BumpInfo = BumpInfo;
end