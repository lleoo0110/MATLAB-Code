function [accuracy, svmMdl] = crossvalidation(X, y, kernelFunction, kernelScale, boxConstraint, k)
    % データをk分割
    cv = cvpartition(y, 'KFold', k);
    
    accuracy = 0;
    for i = 1:k
        % 学習データとテストデータに分割
        trainIdx = cv.training(i);
        testIdx = cv.test(i);
        
        XTrain = X(trainIdx, :);
        yTrain = y(trainIdx);
        XTest = X(testIdx, :);
        yTest = y(testIdx);
        
        % SVMモデルの学習
        svmMdl = fitcsvm(XTrain, yTrain, 'KernelFunction', kernelFunction, 'KernelScale', kernelScale, 'BoxConstraint', boxConstraint);
        
        % テストデータに対する予測
        yPred = predict(svmMdl, XTest);
        
        % 精度の計算
        accuracy = accuracy + sum(yPred == yTest) / length(yTest);
    end
    
    accuracy = accuracy / k;
end