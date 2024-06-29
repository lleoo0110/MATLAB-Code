function meanAccuracy = blockCrossvalidation(Data, label, numBlocks)

% ラベルをカテゴリカル型に変換
label = categorical(label);

% データの準備
X = Data;
y = label; % ラベルまたはクラス


% SVMのテンプレートの作成
t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto');

% データセットのブロック数を定義
blockSize = floor(size(X, 1) / numBlocks);

% ブロッククロスバリデーションの結果を保存するための変数
accuracy = zeros(numBlocks, 1);

for i = 1:numBlocks
    % ブロックを定義
    startIndex = (i-1) * blockSize + 1;
    endIndex = i * blockSize;
    if i == numBlocks
        endIndex = size(X, 1); % 最後のブロックでデータセットの終わりまで含める
    end
    
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

end
