function filterOrder = getOptimalFilterOrder(srate, lowcut, highcut)
    % srate: サンプリングレート (Hz)
    % lowcut: ローカット周波数 (Hz)
    % highcut: ハイカット周波数 (Hz)

    % 遷移帯域幅の計算 (Hz)
    if lowcut == 0
        transitionBand = 0.15 * highcut;
    elseif highcut == 0 || highcut >= srate/2
        transitionBand = 0.15 * lowcut;
    else
        transitionBand = 0.15 * min(lowcut, highcut);
    end

    % フィルタオーダーの計算
    filterOrder = round(3.3 / (transitionBand / srate));
    
    % オーダーが奇数の場合は偶数に調整
    if mod(filterOrder, 2) ~= 0
        filterOrder = filterOrder + 1;
    end

    % 最小オーダーの設定
    minOrder = max(15, ceil(3 * srate / lowcut));
    filterOrder = max(filterOrder, minOrder);

    % 最大オーダーの制限
    maxOrder = floor(srate / 2);
    filterOrder = min(filterOrder, maxOrder);
end