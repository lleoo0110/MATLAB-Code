function [avgOptimalThresholds, avgAUC] = optimizeThresholds(X, Y, numIterations)
    % 入力:
    % X: 特徴量データ
    % Y: ラベル
    % numIterations: 繰り返し回数
    
    % 出力:
    % avgOptimalThresholds: 平均最適閾値
    % avgAUC: 平均AUC
    
    allThresholds = struct('youden', [], 'accuracy', [], 'f1', []);
    allAUCs = [];
    
    for iter = 1:numIterations
        % データの分割 (8:2)
        cv = cvpartition(Y, 'HoldOut', 0.2);
        X_train = X(cv.training, :);
        Y_train = Y(cv.training);
        X_test = X(cv.test, :);
        Y_test = Y(cv.test);
        
        % モデルのトレーニング
        svmModel = fitcsvm(X_train, Y_train, 'KernelFunction', 'rbf', 'Standardize', true);
        svmProbModel = fitPosterior(svmModel);
        % テストデータで予測
        [~, probEstimates] = predict(svmProbModel, X_test);
        
        % 最適な閾値の計算
        [optimalThresholds, AUC] = calculateOptimalThresholds(Y_test, probEstimates);
        
        % 結果の保存
        allThresholds.youden(iter) = optimalThresholds.youden;
        allThresholds.accuracy(iter) = optimalThresholds.accuracy;
        allThresholds.f1(iter) = optimalThresholds.f1;
        allAUCs(iter) = AUC;
        
        fprintf('Iteration %d completed.\n', iter);
    end
    
    % 平均値の計算
    avgOptimalThresholds = struct();
    avgOptimalThresholds.youden = mean(allThresholds.youden);
    avgOptimalThresholds.accuracy = mean(allThresholds.accuracy);
    avgOptimalThresholds.f1 = mean(allThresholds.f1);
    avgAUC = mean(allAUCs);
    
    % 結果の表示
    fprintf('\nAverage Results over %d iterations:\n', numIterations);
    fprintf('Average Optimal Threshold (Youden''s J): %.4f\n', avgOptimalThresholds.youden);
    fprintf('Average Optimal Threshold (Accuracy): %.4f\n', avgOptimalThresholds.accuracy);
    fprintf('Average Optimal Threshold (F1 Score): %.4f\n', avgOptimalThresholds.f1);
    fprintf('Average AUC: %.4f\n', avgAUC);
end