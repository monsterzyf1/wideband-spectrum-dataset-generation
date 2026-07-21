function x = Func_AddClipping(x)
    xr = real(x);

    clip_ratio = 0.7 + 0.25*rand;  % 40%~80%峰值
%     clip_ratio = 0.4 + 0.4*rand;  % 40%~80%峰值
    clip_level = max(abs(xr)) * clip_ratio;

    xr(xr > clip_level) = clip_level;
    xr(xr < -clip_level) = -clip_level;

    if ~isreal(x)
        xi = imag(x);
        xi(xi > clip_level) = clip_level;
        xi(xi < -clip_level) = -clip_level;
        x = xr + 1j*xi;
    else
        x = xr;
    end
end