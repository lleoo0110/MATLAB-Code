function [features] = eogAnalysis(eog_data, sampling_rate, n, inf, sup)
    % EOGデータの前処理と特徴量抽出を行う関数

    % 前処理
    preprocessed_eog = preprocess_eog(eog_data, sampling_rate, n, inf, sup);
    
    % 特徴量抽出
    features = extract_features(preprocessed_eog, sampling_rate);
end

function preprocessed_eog = preprocess_eog(eog_data, sampling_rate)
    % バンドパスフィルタの設計
    bpFilt = designfilt('bandpassfir', 'FilterOrder', n, ...
                        'CutoffFrequency1', inf, 'CutoffFrequency2', sup, ...
                        'SampleRate', sampling_rate);


    % データにフィルタを適用（各チャネルごと）
    filtered_eog = zeros(size(eog_data)); % 初期化
    for ch = 1:size(eog_data, 1)
        filtered_eog(ch, :) = filtfilt(bpFilt, eog_data(ch, :));
    end
    
    % ベースライン補正
    baseline = mean(filtered_eog(1:sampling_rate));  % 最初の1秒をベースラインとする
    corrected_eog = filtered_eog - baseline;
    
    % 正規化
    preprocessed_eog = (corrected_eog - mean(corrected_eog)) / std(corrected_eog);
end

function features = extract_features(eog_data, sampling_rate)
    % 時間領域特徴
    features.mean = mean(eog_data);
    features.std = std(eog_data);
    features.max = max(eog_data);
    features.min = min(eog_data);
    features.range = features.max - features.min;
    
    % 勾配特徴
    gradient = diff(eog_data);
    features.gradient_mean = mean(gradient);
    features.gradient_std = std(gradient);
    
    % 統計的特徴
    features.skewness = skewness(eog_data);
    features.kurtosis = kurtosis(eog_data);
    
    % 周波数領域特徴
    [psd, f] = pwelch(eog_data, [], [], [], sampling_rate);
    features.psd_delta = sum(psd(f >= 0.5 & f < 4));
    features.psd_theta = sum(psd(f >= 4 & f < 8));
    features.psd_alpha = sum(psd(f >= 8 & f < 13));
    features.psd_beta = sum(psd(f >= 13 & f < 30));
    
    % ゼロ交差率
    zero_crossings = sum(diff(sign(eog_data)) ~= 0);
    features.zero_crossing_rate = zero_crossings / length(eog_data);
end

% メイン処理の例
% eog_data = load('eog_data.mat').eog_signal;  % EOGデータの読み込み
% sampling_rate = 256;  % サンプリングレート（Hz）
% features = process_eog_data(eog_data, sampling_rate);