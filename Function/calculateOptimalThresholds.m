function [optimalThresholds, AUC] = calculateOptimalThresholds(Y, probEstimates)
    
    T = linspace(0, 1, 1000);
    
    % 精度の計算
    accuracies = zeros(size(T));
    for i = 1:length(T)
        predictions = probEstimates(:,2) >= T(i);
        accuracies(i) = sum(predictions == Y) / length(Y);
    end
    
    % 最適な精度の閾値
    [maxAccuracy, maxAccIdx] = max(accuracies);
    optimalThresholds.accuracy = T(maxAccIdx);
    
    % ヨーデンのJ統計量の計算
    sensitivity = zeros(size(T));
    specificity = zeros(size(T));
    for i = 1:length(T)
        predictions = probEstimates(:,2) >= T(i);
        sensitivity(i) = sum(predictions & Y) / sum(Y);
        specificity(i) = sum(~predictions & ~Y) / sum(~Y);
    end
    youdenJ = sensitivity + specificity - 1;
    
    % 最適なヨーデンのJ統計量の閾値
    [~, maxYoudenJIdx] = max(youdenJ);
    optimalThresholds.youden = T(maxYoudenJIdx);
    
    % F1スコアの計算
    f1Scores = zeros(size(T));
    for i = 1:length(T)
        predictions = probEstimates(:,2) >= T(i);
        precision = sum(predictions & Y) / sum(predictions);
        recall = sum(predictions & Y) / sum(Y);
        f1Scores(i) = 2 * (precision * recall) / (precision + recall);
    end
    
    % 最適なF1スコアの閾値
    [~, maxF1Idx] = max(f1Scores);
    optimalThresholds.f1 = T(maxF1Idx);
    
    % AUCの計算
    [~, ~, ~, AUC] = perfcurve(Y, probEstimates(:,2), 1);
    
    % プロット
    figure;
    plot(T, accuracies, 'b', 'DisplayName', 'Accuracy');
    hold on;
    plot(T, youdenJ, 'r', 'DisplayName', 'Youden''s J');
    plot(T, f1Scores, 'g', 'DisplayName', 'F1 Score');
    plot(optimalThresholds.accuracy, maxAccuracy, 'bo', 'MarkerSize', 10, 'DisplayName', 'Optimal Accuracy Threshold');
    plot(optimalThresholds.youden, youdenJ(maxYoudenJIdx), 'ro', 'MarkerSize', 10, 'DisplayName', 'Optimal Youden''s J Threshold');
    plot(optimalThresholds.f1, f1Scores(maxF1Idx), 'go', 'MarkerSize', 10, 'DisplayName', 'Optimal F1 Score Threshold');
    xlabel('Threshold');
    ylabel('Performance Metrics');
    title('Performance Metrics vs Threshold');
    legend('Location', 'best');
    grid on;
end