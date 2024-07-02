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
    
%     % ベースライン補正
%     baseline = mean(filtered_data(1:sampling_rate));  % 最初の1秒をベースラインとする
%     corrected_data = filtered_data - baseline;
% 
%     % 正規化
%     preprocessed_eog{i} = (corrected_data - mean(corrected_data)) / std(corrected_data);
end

