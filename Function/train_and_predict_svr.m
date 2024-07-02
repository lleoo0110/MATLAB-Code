function [model, predictions] = train_and_predict_svr(train_features, train_labels, test_features)
    % SVRモデルのトレーニングと予測を行う関数
    
    % SVRモデルのパラメータ設定
    epsilon = 0.1;
    kernel_function = 'rbf';  % ガウシアンカーネル
    kernel_scale = 'auto';
    standardize = true;
    
    % SVRモデルのトレーニング
    model = fitrsvm(train_features, train_labels, ...
        'KernelFunction', kernel_function, ...
        'KernelScale', kernel_scale, ...
        'Epsilon', epsilon, ...
        'Standardize', standardize);
    
    % テストデータに対する予測
    predictions = predict(model, test_features);
end