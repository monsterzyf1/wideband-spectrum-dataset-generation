function [Signal, FSKh, ActualBocc] = c( ...
    ClassName, fs, DataLen, fc, B, Signal_Amp, BExtFactor)

ini_phase = 2*pi*rand;
CNdBLocal = 100;

ClassName = upper(strrep(ClassName,' ', ''));

% FSK/GFSK/MSK/GMSK 调制指数记录；非FSK类为 NaN
FSKh = nan;

% 默认实际标注带宽
% 对 ASK/PAM/PSK/QAM 等调制，默认标签带宽仍使用 B/BExtFactor
ActualBocc = B / BExtFactor;

%% BUOY / 多音浮标信号
if strcmp(ClassName, 'BUOY') || strcmp(ClassName, 'BEACON') || strcmp(ClassName, 'MULTITONE_BUOY')

    Y = Func_GenBuoySignal( ...
        fs, DataLen, fc, B, Signal_Amp, BExtFactor);


%% ASK / OOK
elseif contains(ClassName,'ASK') 

    M = sscanf(ClassName,'%dASK');

    rolloff = 0.25 + 0.20*rand;
    fd = B / BExtFactor / (1 + rolloff);

    SymbLen = ceil(DataLen / (fs/fd)) + 64;
    SymbVec = randi([0 M-1],1,SymbLen);

    if rand < 0.5
        [Y,~] = GenerateMASKWaveRcos( ...
            SymbVec, M, fs, fc, fd, ...
            CNdBLocal, rolloff, ini_phase);
    else
        [Y,~] = GenerateMASKWaveRect( ...
            SymbVec, M, fs, fc, fd, ...
            CNdBLocal, ini_phase);
    end

%% PAM
elseif contains(ClassName,'PAM') || strcmp(ClassName,'OOK')
    
    if strcmp(ClassName,'OOK')
        M = 2;
    else
        M = sscanf(ClassName,'%dPAM');
    end

    rolloff = 0.25 + 0.20*rand;
    fd = B / BExtFactor / (1 + rolloff);

    SymbLen = ceil(DataLen / (fs/fd)) + 64;
    SymbVec = randi([0 M-1],1,SymbLen);

    if rand < 0.5
        [Y,~] = GenerateMPAMWaveRcos( ...
            SymbVec, M, fs, fc, fd, ...
            CNdBLocal, rolloff, ini_phase);
    else
        [Y,~] = GenerateMPAMWaveRect( ...
            SymbVec, M, fs, fc, fd, ...
            CNdBLocal, ini_phase);
    end

%% PSK
elseif contains(ClassName,'PSK')

    if strcmp(ClassName,'BPSK')
        M = 2;
    elseif strcmp(ClassName,'QPSK')
        M = 4;
    else
        M = sscanf(ClassName,'%dPSK');
    end

    rolloff = 0.25 + 0.20*rand;
    fd = B / BExtFactor / (1 + rolloff);

    SymbLen = ceil(DataLen / (fs/fd)) + 64;
    SymbVec = randi([0 M-1],1,SymbLen);

    if rand < 0.5
        [Y,~] = GenerateMPSKWaveRcos( ...
            SymbVec, M, fs, fc, fd, ...
            CNdBLocal, rolloff, ini_phase);
    else
        [Y,~] = GenerateMPSKWaveRect( ...
            SymbVec, M, fs, fc, fd, ...
            CNdBLocal, ini_phase);
    end

%% QAM / QAM_CROSS
elseif contains(ClassName,'QAM')

    isCross = contains(ClassName,'CROSS');

    tmp = regexp(ClassName,'\d+','match');
    M = str2double(tmp{1});

    rolloff = 0.25 + 0.20*rand;
    fd = B / BExtFactor / (1 + rolloff);

    SymbLen = ceil(DataLen / (fs/fd)) + 64;
    SymbVec = randi([0 M-1],1,SymbLen);

    if isCross
        [Y,~] = GenerateMQAMCrossWaveRcos( ...
            SymbVec, M, fs, fc, fd, CNdBLocal, rolloff, ini_phase);
    else
        [Y,~] = GenerateMQAMStandardWaveRcos( ...
            SymbVec, M, fs, fc, fd, CNdBLocal, rolloff, ini_phase);
    end

%% FSK / GFSK / MSK / GMSK
%% ========================================================================
%  FSK / GFSK / MSK / GMSK
% ========================================================================

elseif contains(ClassName,'FSK') || contains(ClassName,'MSK')

    tmp = regexp(ClassName,'\d+','match');
    M = str2double(tmp{1});

    BT = 0.35;

    % 目标占用带宽
    Bocc = B / BExtFactor;

    % -------------------------------------------------------------
    % 为了让时频图能看到明显FSK亮线，需要控制符号率 fd
    % 主程序中 FFTr=11，因此 FFTNum=2048
    % 这里让一个FFT窗里大约只有 2~4 个FSK符号
    % -------------------------------------------------------------
    FFTNumForFSK = 2048;
    SymPerFFT = randi([2,5]);                      % 推荐 2~4，可以用于控制FSK信号的颗粒化
    fd_vis = SymPerFFT * fs / FFTNumForFSK;

    % -------------------------------------------------------------
    % FSK带宽经验公式，沿用你旧代码的思想
    % B ≈ FSKBFactor * fd * (k1 + h*(M-1))
    % -------------------------------------------------------------
    FSKBFactor = 1.2;
    k1 = 0.5;

    % -------------------------------------------------------------
    % h 选择策略
    % -------------------------------------------------------------
    if contains(ClassName,'MSK')
        % MSK/GMSK 固定 h = 0.5
        h = 0.5;

        % 根据带宽反推 fd
        fd = Bocc / FSKBFactor / (k1 + h*(M-1));

        % 防止 fd 太高导致时频图糊成一团
        fd = min(fd, fd_vis);

    else
        % 普通 FSK / GFSK：
        % 优先使用较低符号率 fd_vis，再反推 h
        h_calc = (Bocc / FSKBFactor / fd_vis - k1) / max(M-1,1);

        hMin = 0.5;
        hMax = 6.0;

        if h_calc >= hMin && h_calc <= hMax
            h = h_calc;
            fd = fd_vis;
        else
            h = min(max(h_calc, hMin), hMax);
            fd = Bocc / FSKBFactor / (k1 + h*(M-1));
        end
    end

    fd = max(fd, 1e-6);
    FSKh = h;
    
    % -------------------------------------------------------------
    % 根据最终 fd 和 h 估计实际可见带宽
    % 对 MSK/GMSK 很重要，因为 h 固定为 0.5，
    % 如果 fd 被 fd_vis 限制，实际带宽会明显小于 B/BExtFactor
    % -------------------------------------------------------------
    ActualBocc = FSKBFactor * fd * (k1 + h*(M-1));
    
    % 给一点标注裕量，避免框压得太紧
    if contains(ClassName,'GFSK') || contains(ClassName,'GMSK')
        ActualBocc = ActualBocc * 1.05;
    else
        ActualBocc = ActualBocc * 1.15;
    end
    
    % 不允许超过原始分配带宽
    ActualBocc = min(ActualBocc, B / BExtFactor);
    
    % 至少给 2 个频率 bin，避免小阶 MSK 标签太窄
    MinFreqBinB = 2 * fs / 2048;
    ActualBocc = max(ActualBocc, MinFreqBinB);

    % -------------------------------------------------------------
    % 生成符号
    % -------------------------------------------------------------
    SymbLen = ceil(DataLen / (fs/fd)) + 256;
    SymbVec = randi([0 M-1], 1, SymbLen);

    % -------------------------------------------------------------
    % 生成波形
    % 纯 FSK / MSK 用 Rect，时频亮线更明显
    % GFSK / GMSK 用高斯成形，频率轨迹会更平滑
    % -------------------------------------------------------------
    if contains(ClassName,'GFSK') || contains(ClassName,'GMSK')

        [Y,~,~] = GenerateMGFSKWave( ...
            SymbVec, M, fs, fc, fd, CNdBLocal, h, BT, ini_phase);

    else

        [Y,~,~] = GenerateMFSKWaveRect( ...
            SymbVec, M, fs, fc, fd, CNdBLocal, h, ini_phase);
    end

%% OFDM
elseif contains(ClassName,'OFDM')

    Nsc = ParseOFDMSubcarrierNum(ClassName);

    % 标签给定的目标占用带宽
    Bocc = B / BExtFactor;

    % 关键修改：根据目标带宽反推 Nfft
    % 使实际 OFDM 占用带宽 Nsc/Nfft*fs ≈ Bocc
    Nfft = ceil(Nsc * fs / Bocc);

    % 保证偶数
    Nfft = 2 * ceil(Nfft/2);

    % 至少要能容纳 Nsc 个有效子载波和 DC
    Nfft = max(Nfft, Nsc + 2);

    % 限制最大 IFFT 点数
    NfftMaxOFDM = 131072;

    if Nfft > NfftMaxOFDM
        warning('OFDM Nfft过大，已限制：Class=%s, Nfft=%d -> %d', ...
            ClassName, Nfft, NfftMaxOFDM);
        Nfft = NfftMaxOFDM;
    end

    % 循环前缀
    CP = round(Nfft/8);

    % 保证 OFDM 长度足够
    nOFDMSym = ceil(DataLen / (Nfft + CP)) + 4;

    applyWindow = true;

    [Y,~,~,~,~] = GenerateOFDMWave( ...
        nOFDMSym, Nfft, Nsc, CP, fs, fc, ...
        CNdBLocal, ini_phase, applyWindow);


    
else
    error('未知调制类型: %s', ClassName);
end

Y = Y(:).';

if length(Y) < DataLen
    Y = [Y, zeros(1,DataLen-length(Y))];
else
    Y = Y(1:DataLen);
end

% 当前宽带脚本是实数宽带数据，所以取实部。
% 如果你后续改成复IQ宽带数据，这里不要取 real。
Signal = real(Y);

p = mean(Signal.^2);
if p > 0
    Signal = Signal / sqrt(p) * Signal_Amp;
end

end