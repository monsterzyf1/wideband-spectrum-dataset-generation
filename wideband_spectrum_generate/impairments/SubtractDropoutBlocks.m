function VisibleSegs = SubtractDropoutBlocks(Seg, DropoutBlocks, MinVisibleMs)
% 从一个信号时间段中扣除接收机丢数区间
%
% 输入：
%   Seg           : 一个信号原始可见段，[tbeg_ms, tend_ms]
%   DropoutBlocks : 丢数区间，M x 2
%   MinVisibleMs  : 最小保留时长，单位 ms
%
% 输出：
%   VisibleSegs   : 扣除丢数后的可见信号段，K x 2

    if isempty(Seg) || isempty(DropoutBlocks)
        VisibleSegs = Seg;
        return;
    end

    VisibleSegs = Seg;

    for k = 1:size(DropoutBlocks, 1)

        dBeg = DropoutBlocks(k, 1);
        dEnd = DropoutBlocks(k, 2);

        NewSegs = [];

        for s = 1:size(VisibleSegs, 1)

            sBeg = VisibleSegs(s, 1);
            sEnd = VisibleSegs(s, 2);

            % 无交集
            if dEnd <= sBeg || dBeg >= sEnd
                NewSegs = [NewSegs; sBeg, sEnd];
                continue;
            end

            % 左侧剩余
            if dBeg > sBeg
                NewSegs = [NewSegs; sBeg, min(dBeg, sEnd)];
            end

            % 右侧剩余
            if dEnd < sEnd
                NewSegs = [NewSegs; max(dEnd, sBeg), sEnd];
            end
        end

        VisibleSegs = NewSegs;

        if isempty(VisibleSegs)
            break;
        end
    end

    % 删除太短的残片
    if ~isempty(VisibleSegs)
        dur = VisibleSegs(:,2) - VisibleSegs(:,1);
        VisibleSegs = VisibleSegs(dur >= MinVisibleMs, :);
    end
end