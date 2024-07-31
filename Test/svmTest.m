%% 安静(1) VS オブジェクト前方移動(2)
% CSPデータセット
[cspClass1, cspClass2, cspFilters] = processCSPData2Class(dataClass1, dataClass2);
SVMDataSet = [cspClass1; cspClass2];
SVMLabels = [labelClassA; labelClassB];

% 分類精度計算
meanAccuracy = zeros(1, 1);
% データ
X = SVMDataSet;
y = SVMLabels;

% 修正後モデル
t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto');

% [bestAccuracy, bestParams] = optimizeGridSearch(X12, y12, kernelFunctions, kernelScale, boxConstraint, K);
% t = templateSVM('KernelFunction', bestParams.kernelFunction{1}, 'KernelScale', bestParams.kernelScale, 'BoxConstraint', bestParams.boxConstraint);

svmMdl = fitcecoc(X, y, 'Learners', t);

% クロスバリデーションによる平均分類誤差の計算
CVSVMModel = crossval(svmMdl, 'KFold', K); % Kは分割数
loss = kfoldLoss(CVSVMModel);
meanAccuracy = 1-loss;


disp(['Class 1: ', num2str(size(dataClass1, 1))]);
disp(['Class 2: ', num2str(size(dataClass2, 1))]);
disp(['Accuracy12', '：', num2str(meanAccuracy * 100), '%']);
