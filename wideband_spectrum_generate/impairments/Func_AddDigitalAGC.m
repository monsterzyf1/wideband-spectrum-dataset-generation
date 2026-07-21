function Signal_Out = Func_AddDigitalAGC(Signal)
% Func_AddDigitalAGC 模拟数字自动增益控制 (TorchSig风格)
% 该函数包含随机参数生成和逐样本的反馈控制环路
%
% 输入:
%   Signal: 包含噪声的总信号 (建议是复数行向量)
% 输出:
%   Signal_Out: 经过AGC增益调整后的信号

     % --- 1. 参数定义 (针对 6400Hz 低采样率优化) ---
    
    % 增益初始值 (dB)
    InitGain_Range = [0, 0]; 
%     
    AlphaSmooth_Range  = [1e-5, 5e-4];
    AlphaTrack_Range   = [1e-6, 5e-5];
    AlphaOverflow_Range = [0.005, 0.05];
    AlphaAcquire_Range  = [1e-4, 2e-3];
    
    % 平滑系数: 决定电平检测的灵敏度
    % 原值 1e-6 -> 改为 0.01 (约 100 个点，15ms 平滑一次)
%     AlphaSmooth_Range = [0.01, 0.05]; 
    
    % 跟踪模式下的调整速率 (Track)
    % 原值 1e-5 -> 改为 0.001 (慢速调整)
%     AlphaTrack_Range = [0.0005, 0.002];
    
    % 溢出模式下的调整速率 (Overflow - 极快)
    % 遇到强信号瞬间压低增益
%     AlphaOverflow_Range = [0.1, 0.5];
    
    % 捕获模式下的调整速率 (Acquire - 快)
    % 信号消失后，快速拉高噪声基底
%     AlphaAcquire_Range = [0.01, 0.05];
    
    % 跟踪锁定范围 (dB)
    TrackRange_Range = [0.5, 2];
    
    % --- 2. 随机生成当前次仿真的 AGC 参数 ---
    % 辅助函数：对数均匀分布采样 10^(rand * (log10(max)-log10(min)) + log10(min))
    get_log_rand = @(r) 10^(rand * (log10(r(2)) - log10(r(1))) + log10(r(1)));
    get_uni_rand = @(r) rand * (r(2) - r(1)) + r(1);

    cur_gain_db = get_uni_rand(InitGain_Range);
    alpha_smooth = get_log_rand(AlphaSmooth_Range);
    alpha_track  = get_log_rand(AlphaTrack_Range);
    alpha_overflow = get_log_rand(AlphaOverflow_Range);
    alpha_acquire  = get_log_rand(AlphaAcquire_Range);
    track_range_db = get_uni_rand(TrackRange_Range);

    % --- 3. 预处理：确定参考电平 (Reference Level) ---
    % 计算输入信号幅度的对数均值，用于设定合理的 AGC 目标
    % 避免 AGC 刚开始就剧烈震荡
    abs_sig = abs(Signal);
    % 替换 0 值防止 log 报错
    min_val = min(abs_sig(abs_sig > 0));
    if isempty(min_val), min_val = 1e-6; end
    abs_sig(abs_sig == 0) = min_val * 1e-6;
    
    mean_db = mean(log(abs_sig)); % 自然对数基底，与Python保持一致? TorchSig用np.log
    % 注意：通常通信里用 log10，但这里为了对其代码，我们用 log (ln) 或者统一转 dB
    % 为了物理意义明确，建议统一使用 20*log10 体系。
    % 这里我们用标准 dB 体系：
    mean_db_real = mean(20*log10(abs_sig));
    
    % 目标电平在均值附近 +/- 5dB 随机浮动
    ref_level_db = mean_db_real + (rand * 10 - 5);
    
    % 定义工作边界
    high_level_db = ref_level_db + 10;
    
    % --- 4. 逐样本 AGC 循环 (Sample-by-Sample Loop) ---
    N = length(Signal);
    Signal_Out = zeros(size(Signal));
    
    % 初始化平滑电平
    smoothed_level_db = mean_db_real; 
    
    current_gain_db = cur_gain_db;
    
    for i = 1:N
        % 1. 应用当前增益
        % 增益通常是乘性因子: gain_lin = 10^(gain_db/20)
        gain_lin = 10^(current_gain_db / 20);
        
        val_in = Signal(i);
        val_out = val_in * gain_lin;
        Signal_Out(i) = val_out;
        
        % 2. 测量输出电平 (取模)
        % 也可以测量输入电平，但反馈式AGC通常测量输出
        mag_out = abs(val_out);
        if mag_out == 0, mag_out = 1e-9; end
        inst_db = 20*log10(mag_out);
        
        % 3. 平滑电平估计 (一阶 IIR)
        % level_n = alpha * inst + (1-alpha) * level_prev
        smoothed_level_db = alpha_smooth * inst_db + (1 - alpha_smooth) * smoothed_level_db;
        
        % 4. 计算误差
        error_db = ref_level_db - smoothed_level_db;
        
        % 5. 状态机：选择调整速率 (Alpha)
        if smoothed_level_db > high_level_db
            % 溢出状态 (Overflow): 信号太强，快速降低增益
            cur_alpha = alpha_overflow;
        elseif abs(error_db) < track_range_db
            % 跟踪状态 (Track): 误差很小，慢速微调
            cur_alpha = alpha_track;
        else
            % 捕获状态 (Acquire): 误差较大，中速调整
            cur_alpha = alpha_acquire;
        end
        
        % 6. 更新增益
        % 如果输出太小 (error > 0)，需要增加增益 (+ error)
        current_gain_db = current_gain_db + cur_alpha * error_db;
    end
end
