function x = Func_AddSlowFading(x, fs)
% 快速慢衰落：不用长卷积，不做大FFT

    N = length(x);

    CtrlNum = randi([8, 20]);
    CtrlPos = round(linspace(1, N, CtrlNum));

    FadeDepth_dB = 3 + 9 * rand;
    CtrlGain_dB = FadeDepth_dB * randn(1, CtrlNum) / 3;

    Gain_dB = interp1(CtrlPos, CtrlGain_dB, 1:N, 'pchip');

    Gain = 10.^(Gain_dB / 20);

    x = x .* Gain;
end