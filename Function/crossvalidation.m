function [meanAccuracy, svmMdl] = crossvalidation(Data, label, K)
% SVMモデルの学習
X = Data;
y = label;

c = cvpartition(length(y), 'KFold', K);
opts = struct('CVPartition', c, 'AcquisitionFunctionName', 'expected-improvement-plus');
svmMdl = fitcsvm(X, y, 'OptimizeHyperparameters', 'auto', 'HyperparameterOptimizationOptions', opts);
% svmMdl = fitcsvm(X, y, 'OptimizeHyperparameters', 'auto');

% 交差検証による精度評価
CVSVMModel = crossval(svmMdl, 'KFold', K);
loss = kfoldLoss(CVSVMModel);
meanAccuracy = 1 - loss;
end