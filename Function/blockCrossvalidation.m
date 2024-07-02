function [meanAccuracy, stdAccuracy, accuracies, confMat, f1Score] = blockCrossvalidation(Data, label, numBlocks, classifierFun)
    % Input validation
    if ~isequal(size(Data, 1), length(label))
        error('Number of samples in Data and label must match.');
    end
    
    if nargin < 4
        classifierFun = @(X, y) fitcsvm(X, y, 'Standardize', true);
    end

    label = categorical(label);
    X = Data;
    y = label; 

    blockSize = floor(size(X, 1) / numBlocks);

    accuracies = zeros(numBlocks, 1);
    confMat = zeros(length(categories(y)));
    
    for i = 1:numBlocks
        startIndex = (i-1) * blockSize + 1;
        endIndex = min(i * blockSize, size(X, 1));

        testIdx = startIndex:endIndex;
        trainIdx = setdiff(1:size(X,1), testIdx);

        X_test = X(testIdx, :);
        y_test = y(testIdx);
        X_train = X(trainIdx, :);
        y_train = y(trainIdx);

        % Train the classifier
        model = classifierFun(X_train, y_train);

        % Predict and evaluate
        predictions = predict(model, X_test);
        accuracies(i) = sum(predictions == y_test) / length(y_test);
        
        confMat = confMat + confusionmat(y_test, predictions);
    end

    % Calculate mean accuracy and standard deviation
    meanAccuracy = mean(accuracies);
    stdAccuracy = std(accuracies);
    
    % Calculate overall F1 score
    f1Score = calculateF1Score(confMat);
end

function f1 = calculateF1Score(confMat)
    precision = diag(confMat) ./ sum(confMat, 1)';
    recall = diag(confMat) ./ sum(confMat, 2);
    
    f1 = 2 * (precision .* recall) ./ (precision + recall);
    f1(isnan(f1)) = 0;  % Handle division by zero
    f1 = mean(f1);
end