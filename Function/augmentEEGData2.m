function [augmented_data, augmented_labels] = augmentEEGData2(eeg_data, labels, params)
    % デフォルトパラメータの設定
    default_params = struct(...
        'numAugmentations', 1, ...
        'maxShiftRatio', 0.1, ...
        'noiseLevel', 0.05, ...
        'freqModRange', [0.95, 1.05], ...
        'ampScaleRange', [0.8, 1.2], ...
        'channelSwapProb', 0.2, ...
        'segmentMixProb', 0.3, ...
        'filterRange', [0.5, 30], ...
        'baselineWanderAmp', 0.05 ...
    );

    % パラメータの設定
    if nargin < 3
        params = default_params;
    else
        params = mergeStructs(default_params, params);
    end

    num_datasets = numel(eeg_data);
    [n_channels, n_timepoints] = size(eeg_data{1});

    augmented_data = cell((params.numAugmentations + 1) * num_datasets, 1);
    augmented_labels = zeros((params.numAugmentations + 1) * num_datasets, 1);

    idx = 1;
    for i = 1:num_datasets
        data = eeg_data{i};
        label = labels(i);
        max_shift = round(n_timepoints * params.maxShiftRatio);

        augmented_data{idx} = data;
        augmented_labels(idx) = label;
        idx = idx + 1;

        for j = 1:params.numAugmentations
            aug_data = zeros(n_channels, n_timepoints);

            for ch = 1:n_channels
                % 時間シフト
                shift = randi([-max_shift, max_shift]);
                shifted_data = circshift(data(ch,:), shift);

                % ノイズ付加
                noise = params.noiseLevel * std(data(ch,:)) * randn(1, n_timepoints);
                aug_data(ch,:) = shifted_data + noise;

                % 周波数変調
                aug_data(ch,:) = freqModulation(aug_data(ch,:), params.freqModRange);

                % 振幅スケーリング
                aug_data(ch,:) = ampScaling(aug_data(ch,:), params.ampScaleRange);

                % ベースライン変動
                aug_data(ch,:) = baselineWander(aug_data(ch,:), params.baselineWanderAmp);
            end

            % チャンネル置換
            aug_data = channelSwap(aug_data, params.channelSwapProb);

            % フィルタリング
            aug_data = bandpassFilter(aug_data, params.filterRange, n_timepoints);

            % セグメント置換（Mixup）
            if rand < params.segmentMixProb && i < num_datasets
                aug_data = segmentMix(aug_data, eeg_data{i+1});
            end

            augmented_data{idx} = aug_data;
            augmented_labels(idx) = label;
            idx = idx + 1;
        end
    end
end

% 補助関数

function out = mergeStructs(s1, s2)
    out = s1;
    f = fieldnames(s2);
    for i = 1:length(f)
        if isfield(s1, f{i})
            out.(f{i}) = s2.(f{i});
        end
    end
end

function out = freqModulation(data, range)
    mod_factor = range(1) + (range(2) - range(1)) * rand;
    L = length(data);
    t = (0:L-1)/L;
    phase = 2*pi*t*mod_factor;
    out = real(hilbert(data) .* exp(1i*phase));
end

function out = ampScaling(data, range)
    scale = range(1) + (range(2) - range(1)) * rand;
    out = data * scale;
end

function out = channelSwap(data, prob)
    [n_channels, ~] = size(data);
    out = data;
    for ch = 1:n_channels-1
        if rand < prob
            temp = out(ch,:);
            out(ch,:) = out(ch+1,:);
            out(ch+1,:) = temp;
        end
    end
end

function out = segmentMix(data1, data2)
    [~, L] = size(data1);
    mix_point = randi([1, L-1]);
    out = [data1(:,1:mix_point), data2(:,mix_point+1:end)];
end

function out = baselineWander(data, amp)
    L = length(data);
    t = (0:L-1)'/L;
    wander = amp * sin(2*pi*0.1*t);  % 0.1 Hzの低周波変動
    out = data + wander';
end

function out = bandpassFilter(data, range, L)
    [b, a] = butter(4, range/(L/2), 'bandpass');
    out = filtfilt(b, a, data')';
end