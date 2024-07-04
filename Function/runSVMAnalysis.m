function svmMdl = runSVMAnalysis(X, y, params, K, modelType, useOptimization, classifierName)
    % modelType: 'svm' または 'ecoc'
    % useOptimization: true または false
    
    % ユニークなクラスラベルを取得し、昇順にソート
    uniqueClasses = sort(unique(y));

    if strcmp(modelType, 'svm')
        % SVMモデル
        if ~useOptimization
            svmMdl = fitcsvm(X, y, 'Standardize', true, 'ClassNames', uniqueClasses);
        else
            svmMdl = fitcsvm(X, y, 'OptimizeHyperparameters', 'auto', 'Standardize', true, 'ClassNames', uniqueClasses);
        end
        svmMdl = fitPosterior(svmMdl); % 確率モデルに変換

    elseif strcmp(modelType, 'ecoc')
        % ECOCモデル
        if ~useOptimization
            t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto');
        else
            % グリッドサーチによる最適化
            [~, bestParams] = optimizeGridSearch(X, y, params.kernelFunctions, params.kernelScale, params.boxConstraint, K);
            t = templateSVM('KernelFunction', bestParams.kernelFunction(1), 'KernelScale', bestParams.kernelScale, 'BoxConstraint', bestParams.boxConstraint);
        end
        svmMdl = fitcecoc(X, y, 'Learners', t);
        
    else
        error('Invalid model type. Choose either "svm" or "ecoc".');
    end

    % 交差検証
    CVSVMModel = crossval(svmMdl, 'KFold', K); 
    loss = kfoldLoss(CVSVMModel);
    meanAccuracy = 1 - loss;

    % 結果の表示
    fprintf('\n==== Results for %s ====\n', classifierName);
    fprintf('Model Type: %s\n', modelType);
    fprintf('Optimization: %s\n', string(useOptimization));
    fprintf('Accuracy: %.2f%%\n', meanAccuracy * 100);
    fprintf('----------------------------------------\n\n');
end