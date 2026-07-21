function BlocksOut = MergeTimeBlocks(BlocksIn)
% 合并重叠或相接的时间区间
%
% 输入：
%   BlocksIn : N x 2，每行为 [beg, end]
%
% 输出：
%   BlocksOut : 合并后的区间

    if isempty(BlocksIn)
        BlocksOut = [];
        return;
    end

    BlocksIn = sortrows(BlocksIn, 1);

    BlocksOut = BlocksIn(1, :);

    for k = 2:size(BlocksIn, 1)

        cur = BlocksIn(k, :);
        last = BlocksOut(end, :);

        if cur(1) <= last(2)
            BlocksOut(end, 2) = max(last(2), cur(2));
        else
            BlocksOut = [BlocksOut; cur];
        end
    end
end