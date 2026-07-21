%仅考虑累计时长超过10ms，没有基于估计CNR过滤
clear; clc;

RootFold = 'data/Fs6400KHz_Time1.638400e+02ms_20260625';

OldLabelFold = fullfile(RootFold, 'labels');
NewLabelFold = fullfile(RootFold, 'labels_freq_only');

if ~exist(NewLabelFold, 'dir')
    mkdir(NewLabelFold);
end

% ============================================================
% 一维标签筛选阈值
% 现在只考虑累计可见时间，不考虑 CNR
% ============================================================

MinCumVisibleMs = 10.0;       % 累计可见时间阈值，单位 ms

XmlFiles = dir(fullfile(OldLabelFold, '*.xml'));

for k = 1:length(XmlFiles)

    OldXmlPath = fullfile(OldLabelFold, XmlFiles(k).name);
    NewXmlPath = fullfile(NewLabelFold, XmlFiles(k).name);

    Doc = xmlread(OldXmlPath);

    filename  = GetXmlText(Doc, 'filename');
    folder    = GetXmlText(Doc, 'folder');
    fsKHzStr  = GetXmlText(Doc, 'fsKHz');
    timemsStr = GetXmlText(Doc, 'timems');

    timems = str2double(timemsStr);

    width  = str2double(GetXmlText(Doc, 'width'));
    height = str2double(GetXmlText(Doc, 'height'));
    depth  = str2double(GetXmlText(Doc, 'depth'));

    Objects = Doc.getElementsByTagName('object');

    % ============================================================
    % 1. 读取原 XML 中所有 object 信息
    % ============================================================

    ObjInfo = struct([]);
    SignalIds = [];

    for n = 0:Objects.getLength-1

        Obj = Objects.item(n);

        num_f = str2double(GetChildText(Obj, 'num_f'));
        if isnan(num_f)
            num_f = n + 1;
        end

        BoxNode = Obj.getElementsByTagName('bndbox').item(0);
        if isempty(BoxNode)
            continue;
        end

        xmin = str2double(GetChildText(BoxNode, 'xmin'));
        xmax = str2double(GetChildText(BoxNode, 'xmax'));
        ymin = str2double(GetChildText(BoxNode, 'ymin'));
        ymax = str2double(GetChildText(BoxNode, 'ymax'));

        EstimatedCNRdB = str2double(GetChildText(Obj, 'EstimatedCNRdB'));

        CurIdx = length(ObjInfo) + 1;

        ObjInfo(CurIdx).num_f = num_f;

        % 保留原始类别和调制信息
        ObjInfo(CurIdx).modtype = GetChildText(Obj, 'modtype');
        ObjInfo(CurIdx).name = GetChildText(Obj, 'name');
        ObjInfo(CurIdx).classid = GetChildText(Obj, 'classid');

        % 保留原始功率信息
        ObjInfo(CurIdx).NominalCNdB = GetChildText(Obj, 'NominalCNdB');
        ObjInfo(CurIdx).EstimatedCNRdB = EstimatedCNRdB;

        % 保留原始频率信息
        ObjInfo(CurIdx).fminKHz = GetChildText(Obj, 'fminKHz');
        ObjInfo(CurIdx).fmaxKHz = GetChildText(Obj, 'fmaxKHz');

        % 保留原始框信息
        ObjInfo(CurIdx).xmin = xmin;
        ObjInfo(CurIdx).xmax = xmax;
        ObjInfo(CurIdx).ymin = ymin;
        ObjInfo(CurIdx).ymax = ymax;

        SignalIds(end+1) = num_f;
    end

    UniqueSignalIds = unique(SignalIds, 'stable');

    % ============================================================
    % 2. 按 num_f 分组判断是否保留
    % ============================================================

    NewObjList = struct([]);
    NewObjCount = 0;

    for s = 1:length(UniqueSignalIds)

        CurId = UniqueSignalIds(s);
        idx = find([ObjInfo.num_f] == CurId);

        if isempty(idx)
            continue;
        end

        FirstIdx = idx(1);

        % --------------------------------------------------------
        % 当前信号的原始频率范围和原始 x 范围
        % 注意：这里保留原来的 xmin / xmax，不重新计算
        % --------------------------------------------------------

        OrigXmin = min([ObjInfo(idx).xmin]);
        OrigXmax = max([ObjInfo(idx).xmax]);

        if any(isnan([OrigXmin, OrigXmax]))
            continue;
        end

        OrigX1 = max(1, min(width, floor(OrigXmin)));
        OrigX2 = max(1, min(width, ceil(OrigXmax)));

        if OrigX2 < OrigX1
            continue;
        end

        % --------------------------------------------------------
        % 在原始频率范围内累计可见时间
        %
        % 注意：
        % 这里不再使用 EstimatedCNRdB 过滤
        % 所有有效 object 都参与累计可见时间
        % --------------------------------------------------------

        CumVisibleMsPerX = zeros(1, width);
        BestEstimatedCNRdB = -inf;

        for ii = 1:length(idx)

            CurObj = ObjInfo(idx(ii));

            % CNR 不参与筛选，只用于记录最佳值
            CurEstimatedCNRdB = CurObj.EstimatedCNRdB;
            if isfinite(CurEstimatedCNRdB)
                BestEstimatedCNRdB = max(BestEstimatedCNRdB, CurEstimatedCNRdB);
            end

            xmin = CurObj.xmin;
            xmax = CurObj.xmax;
            ymin = CurObj.ymin;
            ymax = CurObj.ymax;

            if any(isnan([xmin, xmax, ymin, ymax]))
                continue;
            end

            ymin = max(1, min(height, ymin));
            ymax = max(1, min(height, ymax));

            if ymax <= ymin
                continue;
            end

            CurVisibleMs = (ymax - ymin) / height * timems;

            if CurVisibleMs <= 0
                continue;
            end

            x1 = max(1, min(width, floor(xmin)));
            x2 = max(1, min(width, ceil(xmax)));

            if x2 < x1
                continue;
            end

            CumVisibleMsPerX(x1:x2) = CumVisibleMsPerX(x1:x2) + CurVisibleMs;
        end

        % --------------------------------------------------------
        % 判断该信号是否保留
        %
        % 只考虑累计可见时间：
        % 原始频率范围内每一个频点的累计可见时间都需要 >= 10 ms
        %
        % 不再考虑 EstimatedCNRdB
        % --------------------------------------------------------

        CurBandCumVisible = CumVisibleMsPerX(OrigX1:OrigX2);

        if isempty(CurBandCumVisible)
            continue;
        end

        if any(CurBandCumVisible < MinCumVisibleMs)
            continue;
        end

        % --------------------------------------------------------
        % 保留该信号
        % 一维框只改 y 方向，x 和 f 频率信息保留原始值
        % --------------------------------------------------------

        NewObjCount = NewObjCount + 1;

        NewObjList(NewObjCount).num_f = CurId;

        NewObjList(NewObjCount).modtype = ObjInfo(FirstIdx).modtype;
        NewObjList(NewObjCount).name = ObjInfo(FirstIdx).name;
        NewObjList(NewObjCount).classid = ObjInfo(FirstIdx).classid;

        NewObjList(NewObjCount).NominalCNdB = ObjInfo(FirstIdx).NominalCNdB;

        % 原始频率信息：不修改
        NewObjList(NewObjCount).fminKHz = ObjInfo(FirstIdx).fminKHz;
        NewObjList(NewObjCount).fmaxKHz = ObjInfo(FirstIdx).fmaxKHz;

        % 原始 x 信息：不修改
        NewObjList(NewObjCount).xmin = OrigXmin;
        NewObjList(NewObjCount).xmax = OrigXmax;

        % y 方向改成整幅图高度
        NewObjList(NewObjCount).ymin = 1;
        NewObjList(NewObjCount).ymax = height;

        % 记录该信号在原始频率范围内的最小累计可见时间
        NewObjList(NewObjCount).CumVisibleMs = min(CurBandCumVisible);

        % 仅记录最佳 EstimatedCNRdB，不参与筛选
        NewObjList(NewObjCount).BestEstimatedCNRdB = BestEstimatedCNRdB;
    end

    % ============================================================
    % 3. 写新的 XML
    % ============================================================

    Fid = fopen(NewXmlPath, 'w', 'n', 'UTF-8');

    if Fid < 0
        error('无法创建文件: %s', NewXmlPath);
    end

    fprintf(Fid, '<annotation>\n');
    fprintf(Fid, '\t<folder>%s</folder>\n', folder);
    fprintf(Fid, '\t<filename>%s</filename>\n', filename);
    fprintf(Fid, '\t<fsKHz>%s</fsKHz>\n', fsKHzStr);
    fprintf(Fid, '\t<timems>%s</timems>\n', timemsStr);

    fprintf(Fid, '\t<label_type>freq_only_1d_keep_origin_x_and_f_time_only</label_type>\n');
    fprintf(Fid, '\t<MinCumVisibleMs>%g</MinCumVisibleMs>\n', MinCumVisibleMs);
    fprintf(Fid, '\t<CNRFilterUsed>false</CNRFilterUsed>\n');

    fprintf(Fid, '\t<signalnum>%d</signalnum>\n', NewObjCount);

    fprintf(Fid, '\t<size>\n');
    fprintf(Fid, '\t\t<width>%d</width>\n', width);
    fprintf(Fid, '\t\t<height>%d</height>\n', height);
    fprintf(Fid, '\t\t<depth>%d</depth>\n', depth);
    fprintf(Fid, '\t</size>\n');

    for s = 1:NewObjCount

        fprintf(Fid, '\t<object>\n');

        fprintf(Fid, '\t\t<num_id>%d</num_id>\n', s);
        fprintf(Fid, '\t\t<num_f>%d</num_f>\n', NewObjList(s).num_f);

        % 保留原始调制方式、常在/突发名称、类别 ID
        fprintf(Fid, '\t\t<modtype>%s</modtype>\n', NewObjList(s).modtype);
        fprintf(Fid, '\t\t<name>%s</name>\n', NewObjList(s).name);
        fprintf(Fid, '\t\t<classid>%s</classid>\n', NewObjList(s).classid);

        fprintf(Fid, '\t\t<NominalCNdB>%s</NominalCNdB>\n', NewObjList(s).NominalCNdB);

        % BestEstimatedCNRdB 仅作为记录字段，不参与筛选
        if isfinite(NewObjList(s).BestEstimatedCNRdB)
            fprintf(Fid, '\t\t<BestEstimatedCNRdB>%1.3f</BestEstimatedCNRdB>\n', ...
                NewObjList(s).BestEstimatedCNRdB);
        else
            fprintf(Fid, '\t\t<BestEstimatedCNRdB>NaN</BestEstimatedCNRdB>\n');
        end

        fprintf(Fid, '\t\t<CumVisibleMs>%1.3f</CumVisibleMs>\n', ...
            NewObjList(s).CumVisibleMs);

        % 保留原始 f 频率信息
        fprintf(Fid, '\t\t<fminKHz>%s</fminKHz>\n', NewObjList(s).fminKHz);
        fprintf(Fid, '\t\t<fmaxKHz>%s</fmaxKHz>\n', NewObjList(s).fmaxKHz);

        fprintf(Fid, '\t\t<bndbox>\n');

        % 保留原始 x 坐标
        fprintf(Fid, '\t\t\t<xmin>%1.3f</xmin>\n', NewObjList(s).xmin);
        fprintf(Fid, '\t\t\t<xmax>%1.3f</xmax>\n', NewObjList(s).xmax);

        % y 方向改为整幅图高度
        fprintf(Fid, '\t\t\t<ymin>%1.3f</ymin>\n', NewObjList(s).ymin);
        fprintf(Fid, '\t\t\t<ymax>%1.3f</ymax>\n', NewObjList(s).ymax);

        fprintf(Fid, '\t\t</bndbox>\n');

        fprintf(Fid, '\t</object>\n');
    end

    fprintf(Fid, '</annotation>\n');
    fclose(Fid);

    fprintf('完成转换: %s, 保留一维框数 = %d\n', NewXmlPath, NewObjCount);
end


function txt = GetXmlText(Doc, TagName)
    Nodes = Doc.getElementsByTagName(TagName);
    if Nodes.getLength == 0
        txt = '';
    else
        Node = Nodes.item(0);
        if isempty(Node.getFirstChild)
            txt = '';
        else
            txt = char(Node.getFirstChild.getData);
        end
    end
end


function txt = GetChildText(Node, TagName)
    Nodes = Node.getElementsByTagName(TagName);
    if Nodes.getLength == 0
        txt = '';
    else
        CurNode = Nodes.item(0);
        if isempty(CurNode.getFirstChild)
            txt = '';
        else
            txt = char(CurNode.getFirstChild.getData);
        end
    end
end