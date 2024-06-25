function features = extractCSPFeatures4Class(data, cspFilters1, cspFilters2, cspFilters3, cspFilters4)
    % 各クラスに対して特徴量の抽出
    featuresClass1 = extractCSPFeatures(data, cspFilters1);
    featuresClass2 = extractCSPFeatures(data, cspFilters2);
    featuresClass3 = extractCSPFeatures(data, cspFilters3);
    featuresClass4 = extractCSPFeatures(data, cspFilters4);
    
    features = [featuresClass1' featuresClass2' featuresClass3' featuresClass4'];
end