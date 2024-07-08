function preprocessedData = preprocessData(data, Fs, n, inf, sup)
    % バンドパスフィルタの設計
    bpFilt = designfilt('bandpassfir', 'FilterOrder', n, ...
                        'CutoffFrequency1', inf, 'CutoffFrequency2', sup, ...
                        'SampleRate', Fs);


    % データにフィルタを適用（各チャネルごと）
    preprocessedData = zeros(size(data)); % 初期化
    for ch = 1:size(data, 1)
        preprocessedData(ch, :) = filtfilt(bpFilt, data(ch, :));
    end
end

