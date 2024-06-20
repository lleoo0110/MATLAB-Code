function [cspFilters] = calculateCSP(avgCovClass1, avgCovClass2, numFilters)
    % 全体の共分散行列
    compositeCovariance = avgCovClass1 + avgCovClass2;

    % 固有値分解
    % eig関数は、一般化固有値問題に対して使用されます
    [eigVectors, eigValues] = eig(avgCovClass1, compositeCovariance);

    % 固有値を大きい順に並べ替え
    [~, order] = sort(diag(eigValues), 'descend');
    eigVectors = eigVectors(:, order);

    % 最適な固有ベクトルの数を選択
    % numFiltersの値に基づいて最も分離性の高い固有ベクトルを選択
    cspFilters = eigVectors(:, [1:numFilters, end-numFilters+1:end]);
end