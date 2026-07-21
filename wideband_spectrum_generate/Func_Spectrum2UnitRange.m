function yFFT = Func_Spectrum2UnitRange(xFFT,minThd,maxThd)
%    输入：
%    xFFT         - 原始FFT对数谱
%    minThd       - 归一化时的下边界
%    maxThd       - 归一化时的上边界
%    输出：
%    yFFT         - 归一化后的输出

xlen = length(xFFT);
yFFT = zeros(1,xlen);

for k = 1:xlen
    if xFFT(k)>=maxThd
        yFFT(k)=1;
    elseif xFFT(k)<=minThd
        yFFT(k)=0;
    else
        yFFT(k)=(xFFT(k)-minThd)/(maxThd-minThd);
    end
end
