function augmented_data = augmentEEGData(eeg_data, varargin)
    % デフォルトのパラメータ
    default_num_augmentations = 1; % 拡張倍率
    default_max_shift = 100;
    default_noise_level = 0.05;
    
    % 入力パラメータの解析
    p = inputParser;
    addOptional(p, 'num_augmentations', default_num_augmentations, @isnumeric);
    addOptional(p, 'max_shift', default_max_shift, @isnumeric);
    addOptional(p, 'noise_level', default_noise_level, @isnumeric);
    parse(p, varargin{:});
    
    num_augmentations = p.Results.num_augmentations;
    max_shift = p.Results.max_shift;
    noise_level = p.Results.noise_level;
    
    [n_channels, n_timepoints] = size(eeg_data);
    
    % オリジナルデータと拡張データを含む2次元配列を初期化
    augmented_data = zeros(n_channels, n_timepoints * (num_augmentations + 1));
    
    % オリジナルデータを追加
    augmented_data(:, 1:n_timepoints) = eeg_data;
    
    for i = 1:num_augmentations
        start_idx = i * n_timepoints + 1;
        end_idx = (i + 1) * n_timepoints;
        
        for ch = 1:n_channels
            % 各チャンネルごとにシフトとノイズを適用
            shift = randi([-max_shift, max_shift]);
            shifted_data = circshift(eeg_data(ch,:), shift);
            
            % ノイズ付加
            noise = noise_level * std(eeg_data(ch,:)) * randn(1, n_timepoints);
            augmented_data(ch, start_idx:end_idx) = shifted_data + noise;
        end
    end
end