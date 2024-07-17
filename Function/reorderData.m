function [newDataSet, newLabels] = reorderData(DataSet, Labels, numClasses)

    % 各クラスからのサンプル数を計算
    numSamplesPerClass = size(DataSet, 1) / numClasses;

    % 新しいデータセットとラベルの初期化
    newDataSet = zeros(size(DataSet));
    newLabels = zeros(size(Labels));

    % 各クラスから順番にデータを取り出す
    for i = 1:numSamplesPerClass
        for j = 1:numClasses
            index = (j-1)*numSamplesPerClass + i;
            newIndex = (i-1)*numClasses + j;
            newDataSet(newIndex, :) = DataSet(index, :);
            newLabels(newIndex) = Labels(index);
        end
    end
end