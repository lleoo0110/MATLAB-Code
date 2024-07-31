function [augmented_data, augmented_labels] = augmentEEGData(eeg_data, labels, params)
    default_params.numAugmentations = 1;
    default_params.maxShiftRatio = 0.1;
    default_params.noiseLevel = 0.05;

    if nargin < 3
        params = default_params;
    else
        % paramsが構造体でない場合、構造体に変換
        if ~isstruct(params)
            tmp_params = struct();
            field_names = fieldnames(default_params);
            for i = 1:numel(field_names)
                if isfield(params, field_names{i})
                    tmp_params.(field_names{i}) = params.(field_names{i});
                else
                    tmp_params.(field_names{i}) = default_params.(field_names{i});
                end
            end
            params = tmp_params;
        end
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
            end

            augmented_data{idx} = aug_data;
            augmented_labels(idx) = label;
            idx = idx + 1;
        end
    end
end