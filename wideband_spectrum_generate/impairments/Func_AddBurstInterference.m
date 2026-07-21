function x = Func_AddBurstInterference(x, fs, BaseNoiseAmp)

    DataLen = length(x);
%     NumGroups = randi([1, 4]);
    NumGroups = randi([2, 6]);

    for g = 1:NumGroups
        GroupStartIdx = randi([1, floor(DataLen * 0.9)]);
%         NumLines = randi([4, 8]);
        NumLines = randi([6, 12]);

        CurrentIdx = GroupStartIdx;

        for k = 1:NumLines

%             PulseDur_ms = rand * 0.10 + 0.05;   % 0.05~0.15 ms
            PulseDur_ms = rand * 0.05 + 0.02;  % 0.02~0.07 ms
            PulseDurPoints = max(1, round(fs * PulseDur_ms));

            BurstFrag = (randn(1, PulseDurPoints) + ...
                         1j*randn(1, PulseDurPoints)) / sqrt(2);

%             FragAmp = BaseNoiseAmp * (rand * 15 + 10);
            FragAmp = BaseNoiseAmp * (rand * 20 + 10);

            if CurrentIdx + PulseDurPoints - 1 <= DataLen
                x(CurrentIdx:CurrentIdx+PulseDurPoints-1) = ...
                    x(CurrentIdx:CurrentIdx+PulseDurPoints-1) + BurstFrag * FragAmp;
            end

            Gap_ms = rand * 2.0 + 0.5;          % 0.5~2.5 ms
            GapPoints = round(fs * Gap_ms);

            CurrentIdx = CurrentIdx + PulseDurPoints + GapPoints;

            if CurrentIdx >= DataLen
                break;
            end
        end
    end
end