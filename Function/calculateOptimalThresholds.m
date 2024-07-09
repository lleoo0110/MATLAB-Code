function [optimalThresholds, AUC] = calculateOptimalThresholds(Y, probEstimates)
    % ROC曲線の計算
    [X_roc, Y_roc, T, AUC] = perfcurve(Y, probEstimates(:,2), true);
    
    % Youden's J統計量を用いた最適閾値の選択
    [~, optimalIdx] = max(Y_roc - X_roc);
    optimalThresholds.youden = T(optimalIdx);
    
    % 精度最大化による閾値選択
    accuracies = zeros(size(T));
    for i = 1:length(T)
        predictions = probEstimates(:,2) >= T(i);
        accuracies(i) = sum(predictions == Y) / length(Y);
    end
    [~, maxAccIdx] = max(accuracies);
    optimalThresholds.accuracy = T(maxAccIdx);
    
    % F1スコア最大化による閾値選択
    f1Scores = zeros(size(T));
    for i = 1:length(T)
        predictions = probEstimates(:,2) >= T(i);
        precision = sum(predictions & Y) / sum(predictions);
        recall = sum(predictions & Y) / sum(Y);
        f1Scores(i) = 2 * (precision * recall) / (precision + recall);
    end
    [~, maxF1Idx] = max(f1Scores);
    optimalThresholds.f1 = T(maxF1Idx);
    
    % ROC曲線のプロット
    figure;
    plot(X_roc, Y_roc);
    hold on;
    plot([0, 1], [0, 1], 'r--');  % ランダム予測の線
    plot(X_roc(optimalIdx), Y_roc(optimalIdx), 'ko', 'MarkerSize', 10);
    xlabel('False Positive Rate');
    ylabel('True Positive Rate');
    title(['ROC Curve (AUC = ' num2str(AUC) ')']);
    legend('Model', 'Random Guess', 'Optimal Threshold (Youden''s J)', 'Location', 'southeast');
end