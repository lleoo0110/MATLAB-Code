% データの準備
% X = randn(1000, 5);  % 特徴量
% Y = (sum(X, 2) > 0);  % ラベル

X = SVMDataSet;
y = SVMLabels;

% 最適な閾値の計算
[avgOptimalThresholds, avgAUC] = optimizeThresholds(X, y, 10);

% 結果の表示
disp(['Average Optimal Threshold (Youden''s J): ', num2str(avgOptimalThresholds.youden)]);
disp(['Average Optimal Threshold (Accuracy): ', num2str(avgOptimalThresholds.accuracy)]);
disp(['Average Optimal Threshold (F1 Score): ', num2str(avgOptimalThresholds.f1)]);
disp(['Average AUC: ', num2str(avgAUC)]);

metrics = {'Youden''s J', 'Accuracy', 'F1 Score'};
thresholds = [avgOptimalThresholds.youden, avgOptimalThresholds.accuracy, avgOptimalThresholds.f1];

% 全データセットでの最終的な性能評価
svmModel = fitcsvm(X, y, 'KernelFunction', 'rbf', 'Standardize', true);
svmProbModel = fitPosterior(svmModel);
[~, probEstimates] = predict(svmProbModel, X);

for i = 1:length(metrics)
    predictions = probEstimates(:,2) >= thresholds(i);
    accuracy = sum(predictions == y) / length(y);
    precision = sum(predictions & y) / sum(predictions);
    recall = sum(predictions & y) / sum(y);
    f1 = 2 * (precision * recall) / (precision + recall);
    
    disp([metrics{i}, ' Threshold Performance:']);
    disp(['  Accuracy: ', num2str(accuracy)]);
    disp(['  Precision: ', num2str(precision)]);
    disp(['  Recall: ', num2str(recall)]);
    disp(['  F1 Score: ', num2str(f1)]);
    disp(' ');
end


close all;
