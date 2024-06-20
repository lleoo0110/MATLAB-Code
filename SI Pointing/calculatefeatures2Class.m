function [cspFilters, featuresClass] = calculatefeatures2Class(dataClass1, avgCovClass1, avgCovClass2)
    global numFilter
    % CSPフィルタの計算
    cspFilters = calculateCSP(avgCovClass1, avgCovClass2, numFilter);
    
    % 各クラスに対して特徴量の抽出
    featuresClass = extractCSPFeatures(dataClass1, cspFilters);
end