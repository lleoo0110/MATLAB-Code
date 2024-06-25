function bestParams = optimizeGridSearch(X, y, kernelFunctions, kernelScale, boxConstraint)
    % ベストパラメータと最小損失の初期化
    minLoss = inf;
    bestParams = struct();

    % ブロッククロスバリデーション
    for kernelFunction = kernelFunctions
        for scale = kernelScale
            for constraint = boxConstraint
                numBlocks = 10;
                t = templateSVM('KernelFunction', kernelFunction{1}, 'KernelScale', scale, 'BoxConstraint', constraint);

                % データセットのブロックサイズを計算
                blockSize = ceil(size(X, 1) / numBlocks);

                % 精度のための事前割り当て
                accuracy = zeros(numBlocks, 1);

                % 並列処理のためのparforループ
                parfor i = 1:numBlocks
                    % ブロックのインデックスを計算
                    startIndex = (i - 1) * blockSize + 1;
                    endIndex = min(i * blockSize, size(X, 1));

                    % テストセットとトレーニングセットを分割
                    X_test = X(startIndex:endIndex, :);
                    y_test = y(startIndex:endIndex, :);
                    X_train = X([1:startIndex-1, endIndex+1:end], :);
                    y_train = y([1:startIndex-1, endIndex+1:end], :);

                    % モデルの訓練
                    Mdl = fitcecoc(X_train, y_train, 'Learners', t);

                    % テストセットでの評価
                    predictions = predict(Mdl, X_test);
                    accuracy(i) = sum(predictions == y_test) / length(y_test);
                end

                % 全ブロックでの平均精度を計算
                meanAccuracy = mean(accuracy);
                loss = 1 - meanAccuracy;

                if loss < minLoss
                    minLoss = loss;
                    bestParams.kernelFunction = kernelFunction;
                    bestParams.kernelScale = scale;
                    bestParams.boxConstraint = constraint;
                end
            end
        end
    end
end