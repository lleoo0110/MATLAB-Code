function [avgCov] = calculateAverageCovariance(dataClass)
    % データのチャンネル数を取得（セル配列の最初の要素から）
    nChannels = size(dataClass{1, 1}, 1);

    % 平均共分散行列の初期化
    avgCov = zeros(nChannels, nChannels);

    % 各試行の共分散行列を計算し、平均を取る
    for i = 1:size(dataClass, 1)
        singleTrialData = dataClass{i, 1};
        avgCov = avgCov + cov(singleTrialData') / size(dataClass, 1);
    end
end