function [meanAccuracy, stdAccuracy, accuracies, confMat, f1Score, precision, recall] = blockCrossvalidation(Data, label, numBlocks, modelType, useOptimization, isTimeSeries, params)
    % Input validation
    if ~isequal(size(Data, 1), length(label))
        error('Number of samples in Data and label must match.');
    end
    
    if nargin < 4
        modelType = 'svm';
    end
    
    if nargin < 5
        useOptimization = false;
    end
    
    if nargin < 6
        isTimeSeries = true;
    end

    X = Data;
    y = label; 

    numSamples = size(X, 1);
    numClasses = length(unique(y));
    
    % データをシャッフル（時系列でない場合）
    if ~isTimeSeries
        rng('default');
        shuffleIdx = randperm(numSamples);
        X = X(shuffleIdx, :);
        y = y(shuffleIdx);
    end

    % 層化サンプリングのためのインデックスを作成
    stratifiedIdx = stratifiedKFold(y, numBlocks);

    accuracies = zeros(numBlocks, 1);
    confMats = zeros(numClasses, numClasses, numBlocks);
    
    for i = 1:numBlocks
        testIdx = (stratifiedIdx == i);
        trainIdx = ~testIdx;

        X_test = X(testIdx, :);
        y_test = y(testIdx);
        X_train = X(trainIdx, :);
        y_train = y(trainIdx);

        % 分類器の選択と学習
        model = trainClassifier(X_train, y_train, modelType, useOptimization, params, numBlocks);

        % 予測と評価
        predictions = predict(model, X_test);
        accuracies(i) = sum(predictions == y_test) / length(y_test);
        
        tempConfMat = confusionmat(y_test, predictions);
        confMats(1:size(tempConfMat,1), 1:size(tempConfMat,2), i) = tempConfMat;
    end

    % 平均精度と標準偏差の計算
    meanAccuracy = mean(accuracies);
    stdAccuracy = std(accuracies);
    
    % 全体的な混同行列の計算
    confMat = sum(confMats, 3);
    
    % 全体的な性能指標の計算
    [f1Score, precision, recall] = calculatePerformanceMetrics(confMat);
end

function model = trainClassifier(X, y, modelType, useOptimization, params, K)
    uniqueClasses = sort(unique(y));
    
    if strcmp(modelType, 'svm')
        if ~useOptimization
            model = fitcsvm(X, y, 'Standardize', true, 'ClassNames', uniqueClasses);
        else
            model = fitcsvm(X, y, 'OptimizeHyperparameters', 'auto', 'Standardize', true, 'ClassNames', uniqueClasses);
        end
        model = fitPosterior(model);
    elseif strcmp(modelType, 'ecoc')
        if ~useOptimization
            t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto');
        else
            [~, bestParams] = optimizeGridSearch(X, y, params.kernelFunctions, params.kernelScale, params.boxConstraint, K);
            t = templateSVM('KernelFunction', bestParams.kernelFunction(1), 'KernelScale', bestParams.kernelScale, 'BoxConstraint', bestParams.boxConstraint);
        end
        model = fitcecoc(X, y, 'Learners', t);
    else
        error('Invalid model type. Choose either "svm" or "ecoc".');
    end
end

function [f1, precision, recall] = calculatePerformanceMetrics(confMat)
    precision = diag(confMat) ./ sum(confMat, 1)';
    recall = diag(confMat) ./ sum(confMat, 2);
    
    f1 = 2 * (precision .* recall) ./ (precision + recall);
    f1(isnan(f1)) = 0;  % Handle division by zero
    
    % Macro average
    f1 = mean(f1);
    precision = mean(precision);
    recall = mean(recall);
end

function foldIdx = stratifiedKFold(y, k)
    categories = unique(y);
    foldIdx = zeros(size(y));
    
    for i = 1:length(categories)
        catIdx = find(y == categories(i));
        catSize = length(catIdx);
        catFolds = repmat(1:k, 1, ceil(catSize/k));
        catFolds = catFolds(1:catSize);
        catFolds = catFolds(randperm(catSize));
        foldIdx(catIdx) = catFolds;
    end
end