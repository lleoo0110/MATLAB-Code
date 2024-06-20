function bestParams = optimizeGridSearch(X, y, kernelFunctions, kernelScale, boxConstraint)
    bestAccuracy = 0;
    bestParams.kernelFunction = {};
    bestParams.kernelScale = [];
    bestParams.boxConstraint = [];
    
    % グリッドサーチのパラメータの組み合わせを生成
    [KF, KS, BC] = ndgrid(kernelFunctions, kernelScale, boxConstraint);
    params = [KF(:), num2cell(KS(:)), num2cell(BC(:))];
    
    % 並列処理のための変数の初期化
    accuracy = zeros(size(params, 1), 1);
    
    % parforを用いた並列処理
    parfor i = 1:size(params, 1)
        [accuracy(i), ~] = crossvalidation(X, y, params{i, 1}, params{i, 2}, params{i, 3}, 5);
    end
    
    % 最良の結果を取得
    [bestAccuracy, bestIdx] = max(accuracy);
    bestParams.kernelFunction = params{bestIdx, 1};
    bestParams.kernelScale = params{bestIdx, 2};
    bestParams.boxConstraint = params{bestIdx, 3};
end