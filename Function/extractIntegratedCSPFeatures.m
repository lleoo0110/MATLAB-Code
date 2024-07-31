function cspFeatures = extractIntegratedCSPFeatures(DataSet, cspFilters)
    % cspFiltersがcell配列でない場合、cell配列に変換
    if ~iscell(cspFilters)
        cspFilters = {cspFilters};
    end
    
    numCSPFilters = length(cspFilters);
    numFeaturesPerFilter = size(cspFilters{1}, 2);
    
    % DataSetがcell配列かどうかを確認
    if iscell(DataSet)
        totalEpochs = length(DataSet);
        cspFeatures = zeros(totalEpochs, numCSPFilters * numFeaturesPerFilter);
        
        for i = 1:totalEpochs
            epoch = DataSet{i};
            cspFeatures(i, :) = extractFeaturesForEpoch(epoch, cspFilters, numFeaturesPerFilter);
        end
    else
        % DataSetが2次元配列の場合（チャンネル x データポイント）
        cspFeatures = extractFeaturesForEpoch(DataSet, cspFilters, numFeaturesPerFilter);
    end
end

function features = extractFeaturesForEpoch(epoch, cspFilters, numFeaturesPerFilter)
    numCSPFilters = length(cspFilters);
    features = zeros(1, numCSPFilters * numFeaturesPerFilter);
    
    for j = 1:numCSPFilters
        cspFilter = cspFilters{j};
        epochFeatures = extractCSPFeatures(epoch, cspFilter);
        
        startIdx = (j-1) * numFeaturesPerFilter + 1;
        endIdx = j * numFeaturesPerFilter;
        features(startIdx:endIdx) = epochFeatures;
    end
end