X = SVMDataSet;
y = SVMLabels;

% データをk分割
cv = cvpartition(y, 'KFold', K);

yPredAll = [];
yTestAll = [];


% 学習データとテストデータに分割
trainIdx = cv.training(2);
testIdx = cv.test(2);

XTrain = X(trainIdx, :);
yTrain = y(trainIdx);
XTest = X(testIdx, :);
yTest = y(testIdx);

% SVMモデルの学習
svmMdlTrain = fitcsvm(XTrain, yTrain, 'OptimizeHyperparameters', 'auto', 'Standardize', true, 'ClassNames', [1,2]);

% 確率出力を可能にするモデルに変換
svmProbModel = fitPosterior(svmMdlTrain);

% 新しいデータに対する予測
[preLabel, preScores] = predict(svmProbModel, XTest);

% モデルのクラス順序を確認
classOrder = svmProbModel.ClassNames;

