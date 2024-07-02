function [svmMdl, loss] = EOGCrossValidation(features, labels, K)
    % 3クラス分類のためのSVMモデルの交差検証を行う関数
    
    % SVMモデルのパラメータ設定
    template = templateSVM('KernelFunction', 'rbf', 'Standardize', true);
    
    % 交差検証モデルの作成
    cv_model = fitcecoc(features, labels, 'Learners', template, ...
        'CrossVal', 'on', ...
        'KFold', K);
    
    % 交差検証による損失の計算
    loss = kfoldLoss(cv_model);
    
    % 最終モデルの訓練（全データを使用）
    svmMdl = fitcecoc(features, labels, 'Learners', template);
end