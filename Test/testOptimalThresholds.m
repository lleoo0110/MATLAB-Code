X = SVMDataSet;
y = SVMLabels;

% yのデータタイプを確認
fprintf('Original data type of y: %s\n', class(y));

% yを適切なデータタイプに変換
y = uint8(y);

fprintf('Converted data type of y: %s\n', class(y));

% SVMモデルの学習
svmModel = fitcsvm(X, y, 'KernelFunction', 'rbf', 'Standardize', true);
% 確率推定モデルの学習
svmProbModel = fitPosterior(svmModel);
% テストデータに対する確率の予測
[~, probEstimates] = predict(svmProbModel, X);
% 最適な確率閾値の計算
[optimalThresholds, AUC] = calculateOptimalThresholds(y, probEstimates);
% 結果の表示
fprintf('Optimal Threshold (Accuracy): %.3f\n', optimalThresholds.accuracy);
fprintf('Optimal Threshold (Youden''s J): %.3f\n', optimalThresholds.youden);
fprintf('Optimal Threshold (F1 Score): %.3f\n', optimalThresholds.f1);
fprintf('AUC: %.3f\n', AUC);
% 閾値を使用した予測
predictions = probEstimates(:,1) >= optimalThresholds.accuracy;
predictions = uint8(predictions);  % 論理値を uint8 に変換
% 混同行列の計算
confusionMatrix = confusionmat(y, predictions);
fprintf('Confusion Matrix:\n');
disp(confusionMatrix)