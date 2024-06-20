function [cspClass1, cspClass2, cspFilters] = processCSPData2Class(dataClass1, dataClass2)
    % 初期化
    cspClass1 = [];
    cspClass2 = [];
    
    % 各クラスの共分散行列の平均値を取る
    avgCov1 = calculateAverageCovariance(dataClass1);
    avgCov2 = calculateAverageCovariance(dataClass2);

    % 2クラスCSPフィルタ
    for kk = 1:size(dataClass1, 1)
        [cspFilters, cspFeatures1] = calculatefeatures2Class(dataClass1{kk,1}, avgCov1, avgCov2);
        cspClass1(kk,:) = cspFeatures1';
    end
    
     for ll = 1:size(dataClass2, 1)
        [~, cspFeatures2] = calculatefeatures2Class(dataClass2{ll,1}, avgCov1, avgCov2);
        cspClass2(ll,:) = cspFeatures2';
     end
end