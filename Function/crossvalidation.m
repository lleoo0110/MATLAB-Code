function [meanAccuracy, svmMdl] = crossvalidation(Data, label, K)
% SVMモデルの学習
X = Data;
y = label;

svmMdl = fitcsvm(X, y, 'OptimizeHyperparameters', 'auto');

% t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto');
% % SVMモデルの訓練
% svmMdl = fitcecoc(X, y, 'Learners', t);

% 交差検証による精度評価
CVSVMModel = crossval(svmMdl, 'KFold', K);
loss = kfoldLoss(CVSVMModel);
meanAccuracy = 1 - loss;
end