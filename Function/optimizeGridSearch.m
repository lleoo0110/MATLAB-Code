function [bestAccuracy, bestParams] = optimizeGridSearch(X, y, kernelFunctions, kernelScale, boxConstraint, K)
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
        t = templateSVM('KernelFunction', params{i, 1}, 'KernelScale', params{i, 2}, 'BoxConstraint', params{i, 3});
        svmMdl = fitcecoc(X, y, 'Learners', t);
        CVSVMModel = crossval(svmMdl, 'KFold', K); % Kは分割数
        loss = kfoldLoss(CVSVMModel);
        accuracy(i, 1) = 1-loss;
    end
    
    % 最良の結果を取得
    [bestAccuracy, bestIdx] = max(accuracy);
    bestParams.kernelFunction = params{bestIdx, 1};
    bestParams.kernelScale = params{bestIdx, 2};
    bestParams.boxConstraint = params{bestIdx, 3};
end