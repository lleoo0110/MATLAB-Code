function [svmMdl, meanAccuracy] = runSVMAnalysis(X, y, params, K, modelType, useOptimization, classifierName)
    % modelType: 'svm' または 'ecoc'
    % useOptimization: true または false
    
    uniqueClasses = sort(unique(y));

    if strcmp(modelType, 'svm')
        if ~useOptimization
            accuracies = zeros(20, 1);
            for i = 1:100
                svmMdl = fitcsvm(X, y, 'Standardize', true, 'ClassNames', uniqueClasses);
                svmMdl = fitPosterior(svmMdl);
                CVSVMModel = crossval(svmMdl, 'KFold', K);
                loss = kfoldLoss(CVSVMModel);
                accuracies(i) = 1 - loss;
            end
            meanAccuracy = mean(accuracies);
        else
            svmMdl = fitcsvm(X, y, 'OptimizeHyperparameters', 'auto', 'Standardize', true, 'ClassNames', uniqueClasses);
            svmMdl = fitPosterior(svmMdl);
            CVSVMModel = crossval(svmMdl, 'KFold', K);
            loss = kfoldLoss(CVSVMModel);
            meanAccuracy = 1 - loss;
        end
        
    elseif strcmp(modelType, 'ecoc')
        if ~useOptimization
            accuracies = zeros(20, 1);
            for i = 1:100
                t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto');
                svmMdl = fitcecoc(X, y, 'Learners', t);
                CVSVMModel = crossval(svmMdl, 'KFold', K);
                loss = kfoldLoss(CVSVMModel);
                accuracies(i) = 1 - loss;
            end
            meanAccuracy = mean(accuracies);
        else
            [~, bestParams] = optimizeGridSearch(X, y, params.kernelFunctions, params.kernelScale, params.boxConstraint, K);
            t = templateSVM('KernelFunction', bestParams.kernelFunction(1), 'KernelScale', bestParams.kernelScale, 'BoxConstraint', bestParams.boxConstraint);
            svmMdl = fitcecoc(X, y, 'Learners', t);
            CVSVMModel = crossval(svmMdl, 'KFold', K);
            loss = kfoldLoss(CVSVMModel);
            meanAccuracy = 1 - loss;
        end
    else
        error('Invalid model type. Choose either "svm" or "ecoc".');
    end

    % 結果の表示
    fprintf('\n==== Results for %s ====\n', classifierName);
    fprintf('Model Type: %s\n', modelType);
    fprintf('Optimization: %s\n', string(useOptimization));
    fprintf('Accuracy: %.2f%%\n', meanAccuracy * 100);
    fprintf('----------------------------------------\n\n');
end