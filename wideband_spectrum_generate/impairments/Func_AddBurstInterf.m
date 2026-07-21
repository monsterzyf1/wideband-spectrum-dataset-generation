function x = Func_AddBurstInterf(x, fs, BaseNoiseAmp)

    % 短时部分宽带脉冲串干扰
    % 频域覆盖带宽 >= 全带宽一半

    DataLen = length(x);

    NumGroups = randi([1, 4]);

    for g = 1:NumGroups

        GroupStartIdx = randi([1, floor(DataLen * 0.9)]);
        NumLines = randi([4, 8]);

        CurrentIdx = GroupStartIdx;

        for k = 1:NumLines

            PulseDurMs = 0.03 + 0.12*rand;
            L = max(16, round(fs * PulseDurMs));

            if CurrentIdx + L - 1 > DataLen
                break;
            end

            %% 生成短时宽带噪声
            BurstFrag = randn(1, L);

            %% 频域限制：只覆盖一半以上带宽
            Nfft = 2^nextpow2(L);

            X = fft(BurstFrag, Nfft);

            % 正频率范围：1 ~ Nfft/2
            PosN = floor(Nfft/2);

            % 覆盖比例：0.5 ~ 1.0
            CoverRatio = 0.5 + 0.5*rand;

            BandBins = max(2, round(PosN * CoverRatio));

            % 随机起始频点
            StartBin = randi([1, PosN - BandBins + 1]);
            EndBin = StartBin + BandBins - 1;

            Mask = zeros(1, Nfft);

            % 正频率保留
            Mask(StartBin:EndBin) = 1;

            % 负频率共轭位置保留
            NegStart = Nfft - EndBin + 2;
            NegEnd   = Nfft - StartBin + 2;

            NegStart = max(1, NegStart);
            NegEnd   = min(Nfft, NegEnd);

            Mask(NegStart:NegEnd) = 1;

            X = X .* Mask;

            BurstFrag = real(ifft(X, Nfft));
            BurstFrag = BurstFrag(1:L);

            %% 加窗
            if L > 4
                win = hann(L).';
                BurstFrag = BurstFrag .* win;
            end

            %% 幅度
            FragAmp = BaseNoiseAmp * (4 + 10*rand);

            x(CurrentIdx:CurrentIdx+L-1) = ...
                x(CurrentIdx:CurrentIdx+L-1) + BurstFrag * FragAmp;

            %% 间隔
            GapMs = 0.3 + 1.7*rand;
            GapPoints = round(fs * GapMs);

            Jitter = round(GapPoints * (rand - 0.5) * 0.2);

            CurrentIdx = CurrentIdx + L + GapPoints + Jitter;

            if CurrentIdx >= DataLen
                break;
            end
        end
    end
end