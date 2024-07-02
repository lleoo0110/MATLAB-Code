function features_vector = eogAnalysis(eog_data, sampling_rate)
    % 特徴量抽出
    features = extract_features(eog_data, sampling_rate);
    
    % 特徴量をベクトルに変換
    features_vector = features_to_vector(features);
end

function features = extract_features(eog_data, sampling_rate)
    num_cells = numel(eog_data);
    % 特徴量を格納するための構造体配列を初期化
    features = struct('mean', cell(1, num_cells), 'std', cell(1, num_cells), ...
                      'max', cell(1, num_cells), 'min', cell(1, num_cells), ...
                      'range', cell(1, num_cells), 'gradient_mean', cell(1, num_cells), ...
                      'gradient_std', cell(1, num_cells), 'skewness', cell(1, num_cells), ...
                      'kurtosis', cell(1, num_cells), 'psd_delta', cell(1, num_cells), ...
                      'psd_theta', cell(1, num_cells), 'psd_alpha', cell(1, num_cells), ...
                      'psd_beta', cell(1, num_cells), 'zero_crossing_rate', cell(1, num_cells));
    
    for i = 1:num_cells
        current_data = eog_data{i};  % 2 x 256 のデータ
        
        for ch = 1:2  % 2チャンネル分ループ
            channel_data = current_data(ch, :);
            
            % 時間領域特徴
            features(i).mean(ch) = mean(channel_data);
            features(i).std(ch) = std(channel_data);
            features(i).max(ch) = max(channel_data);
            features(i).min(ch) = min(channel_data);
            features(i).range(ch) = features(i).max(ch) - features(i).min(ch);
            
            % 勾配特徴
            gradient = diff(channel_data);
            features(i).gradient_mean(ch) = mean(gradient);
            features(i).gradient_std(ch) = std(gradient);
            
            % 統計的特徴
            features(i).skewness(ch) = skewness(channel_data);
            features(i).kurtosis(ch) = kurtosis(channel_data);
            
            % 周波数領域特徴
            [psd, f] = pwelch(channel_data, [], [], [], sampling_rate);
            features(i).psd_delta(ch) = sum(psd(f >= 0.5 & f < 4));
            features(i).psd_theta(ch) = sum(psd(f >= 4 & f < 8));
            features(i).psd_alpha(ch) = sum(psd(f >= 8 & f < 13));
            features(i).psd_beta(ch) = sum(psd(f >= 13 & f < 30));
            
            % ゼロ交差率
            zero_crossings = sum(diff(sign(channel_data)) ~= 0);
            features(i).zero_crossing_rate(ch) = zero_crossings / length(channel_data);
        end
    end
end

function feature_vector = features_to_vector(features)
    % 特徴量構造体をベクトルに変換
    feature_names = fieldnames(features);
    num_features = length(feature_names) * 2;  % 2チャンネル分
    num_samples = length(features);
    
    feature_vector = zeros(num_samples, num_features);
    
    for i = 1:num_samples
        feature_idx = 1;
        for j = 1:length(feature_names)
            feature_value = features(i).(feature_names{j});
            for ch = 1:2
                feature_vector(i, feature_idx) = feature_value(ch);
                feature_idx = feature_idx + 1;
            end
        end
    end
end