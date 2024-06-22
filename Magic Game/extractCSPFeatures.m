function features = extractCSPFeatures(data, cspFilters)
    % データにCSPフィルタを適用
    filteredData = cspFilters' * data;

    % 特徴量の計算（フィルターされた信号の対数バリアンス）
    features = log(var(filteredData, 0, 2));
end