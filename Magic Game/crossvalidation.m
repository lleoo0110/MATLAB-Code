function [meanAccuracy, Mdl] = crossvalidation(Data, label, kernelFunctions, kernelScale, boxConstraint, K)
% データの準備
X = Data; % 例: 訓練データの特徴量
y = label; % 例: ラベルまたはクラス（複数クラス）

% SVMのテンプレートの作成
% t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto');
t = templateSVM('KernelFunction', kernelFunctions, 'KernelScale', kernelScale, 'BoxConstraint', boxConstraint);

% テンプレートを使用してマルチクラスSVMモデルの訓練
Mdl = fitcecoc(X, y, 'Learners', t);

% クロスバリデーション（オプション）
CVSVMModel = crossval(Mdl, 'KFold', K); % Kは分割数

% クロスバリデーションによる平均分類誤差の計算
loss = kfoldLoss(CVSVMModel);
meanAccuracy = 1-loss;
end