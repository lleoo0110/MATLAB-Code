function cspFeatures = extractIntegratedCSPFeatures(DataSet, cspFilters)
    numCSPFilters = length(cspFilters);

    % 特徴量の次元数（各CSPフィルタから抽出する特徴量の数）
    numFeaturesPerFilter = size(cspFilters{1}, 2);

    % 統合された特徴量行列の初期化
    totalEpochs = length(DataSet);
    cspFeatures = zeros(totalEpochs, numCSPFilters * numFeaturesPerFilter);

    % 各エポックに対してCSPフィルタを適用し，特徴量を抽出
    for i = 1:totalEpochs
        epoch = DataSet{i};
        
        for j = 1:numCSPFilters
            cspFilter = cspFilters{j};
            features = extractCSPFeatures(epoch, cspFilter);

            startIdx = (j-1) * numFeaturesPerFilter + 1;
            endIdx = j * numFeaturesPerFilter;
            cspFeatures(i, startIdx:endIdx) = features;
        end
    end
end