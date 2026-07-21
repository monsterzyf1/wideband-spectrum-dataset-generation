function Signal_Out = Func_AddCoarseGainChange(Signal, GainRange_dB)
% Func_AddCoarseGainChange 模拟接收机增益突变
%
% 输入:
%   Signal: 输入复数信号
%   GainRange_dB: [min, max] 增益突变范围，例如 [-20, 20]
%
% 输出:
%   Signal_Out: 突变后的信号

    % 1. 随机生成突变值 (dB)
    GainChange_dB = rand * (GainRange_dB(2) - GainRange_dB(1)) + GainRange_dB(1);
    
    % 计算线性增益因子
    LinearGain = 10^(GainChange_dB / 20);
    
    % 2. 随机选择突变发生的时间点 (Start Index)
    % 范围: 从第2个点 到 倒数第2个点 (保证突变发生在中间)
    N = length(Signal);
    if N < 3
        Signal_Out = Signal;
        return;
    end
    StartIndex = randi([2, N-1]);
    
    % 3. 应用突变
    % 前半部分保持不变，后半部分乘以增益
    Signal_Out = Signal;
    Signal_Out(StartIndex:end) = Signal(StartIndex:end) * LinearGain;
    
    % (可选调试信息)
    % fprintf('Gain Jump: %.2f dB at Index %d', GainChange_dB, StartIndex);
end
