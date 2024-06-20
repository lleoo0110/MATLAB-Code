function [svm] = svmClassifier(Data, label)
% データの準備
X = Data; % 例: 訓練データの特徴量
y = label; % 例: ラベルまたはクラス（複数クラス）

% SVMのテンプレートの作成
t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto');

% SVMモデルの訓練
svm = fitcecoc(X, y, 'Learners', t);

end