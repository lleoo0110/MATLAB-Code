%% パラメータ設定
global isRunning Ch numFilter csvFilename

% メインパラメータ構造体の初期化
params = struct();

% EEG解析パラメータ
params.eeg = struct(...
    'minf', 1, ...
    'maxf', 30, ...
    'Fs', 256, ...
    'filtOrder', 1024, ...
    'overlap', 1, ...
    'windowSize', 2, ...
    'numFilter', 7, ...
    'K', 5 ...
);

% データ拡張用パラメータ
params.varargin = struct(...
    'numAugmentations', 10, ...
    'maxShiftRatio', 0.2, ...
    'noiseLevel', 0.1 ...
);

% 実験用パラメータ
params.experiment = struct(...
    'name', 'reona', ... % ここを変更
    'portNumber', 12354 ...
);
params.experiment.datasetName = [params.experiment.name '_dataset'];
params.experiment.dataName = params.experiment.name;
params.experiment.csvFilename = [params.experiment.name '_label.csv'];

% 擬似脳波データ生成のためのパラメータを追加
params.simulation = struct(...
    'amplitude', 50, ... % マイクロボルト単位の振幅
    'noise_level', 5 ... % ノイズレベル
);

% SVMパラメータ設定
params.model = struct(...
    'modelType', 'svm', ... % 'svm' or 'ecoc'
    'useOptimization', false, ...
    'kernelFunctions', {{'linear', 'rbf', 'polynomial'}}, ...
    'kernelScale', [0.1, 1, 10], ...
    'boxConstraint', [0.1, 1, 10, 100] ...
);

% EPOCX設定（14Ch）
params.epocx = struct(...
    'channels', {{'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'}}, ... % チャンネル
    'selectedChannels', [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17] ... % 'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'
);

% グローバル変数の設定
isRunning = false;
Ch = params.epocx.channels;
numFilter = params.eeg.numFilter;
csvFilename = params.experiment.csvFilename;


%% 脳波データ計測
disp('データ計測中...');

% GUIの作成と表示
createMovieStartGUI();

% データ初期化
eegData = [];
preprocessedData = [];
labels = [];
stimulusStart = [];
augmentedData = [];
augmentedLabels = [];

while ~isRunning
    % 待機時間
    pause(0.1);
end

% EEGデータ収集
saveInterval = 60; % 保存間隔（秒）
fileIndex = 1;
lastSaveTime = tic;

lastSampleTime = tic;
sampleCounter = 0;
while isRunning
    currentTime = toc(lastSampleTime);
    samplesNeeded = floor(currentTime * params.eeg.Fs) - sampleCounter;
    
    if samplesNeeded > 0
        for i = 1:samplesNeeded
            % 擬似EEGサンプルを生成
            eegSample = generateFakeEEGSample(19, params.simulation.amplitude, params.simulation.noise_level);
            eegData = [eegData eegSample'];
            sampleCounter = sampleCounter + 1;
        end
        
        elapsedTime = toc(lastSaveTime);
        if elapsedTime >= saveInterval
            disp(['Samples collected: ' num2str(size(eegData, 2))]);
            
            save(sprintf('%s_data_%d.mat', params.experiment.dataName, fileIndex), 'eegData');
            eegData = []; % メモリから削除
            lastSaveTime = tic;
            fileIndex = fileIndex + 1; % 連番を増加
        end
    end

    pause(0.0001); % 応答性を保つための短い休止
    
    
    % 1秒ごとにカウンターをリセット
    if currentTime >= 1
        lastSampleTime = tic;
        sampleCounter = 0;
    end
end

% 最後の未保存データを保存
if ~isempty(eegData)
    elapsedTime = toc(lastSaveTime);
    save(sprintf('%s_data_%d.mat', params.experiment.dataName, fileIndex), 'eegData');
end

savedData = [];
fileIndex = 1;
while true
    filename = sprintf('%s_data_%d.mat', params.experiment.dataName, fileIndex);
    if exist(filename, 'file')
        load(filename, 'eegData');
        savedData = [savedData eegData];
        fileIndex = fileIndex + 1;
    else
        break;
    end
end
eegData = savedData; % EEGデータの保存

% データセットを保存
save(params.experiment.datasetName, 'eegData');
disp('データセットが保存されました。');


%% 脳波データの前処理
disp('データ解析中...しばらくお待ちください...');

% データの前処理
preprocessedData = preprocessData(eegData(params.epocx.selectedChannels, :), params.eeg.Fs, params.eeg.filtOrder, params.eeg.minf, params.eeg.maxf);

% ラベル作成
if ~exist('stimulusStart', 'var') || isempty(stimulusStart)
    stimulusStart = readmatrix(csvFilename);
end

% データセットの初期化
nTrials = size(stimulusStart, 1);
totalEpochs = nTrials * params.eeg.overlap;
DataSet = cell(totalEpochs, 1);
labels = zeros(totalEpochs, 1);

epochIndex = 1;
for ii = 1:nTrials
    startIdx = round(params.eeg.Fs * (stimulusStart(ii, 2)-1)) + 1;
    endIdx = startIdx + params.eeg.Fs * params.eeg.windowSize - 1;
    
    % エポック化
    for jj = 1:params.eeg.overlap
        shiftAmount = round((jj - 1) * params.eeg.Fs * 1);  % 1秒ずつ時間窓をずらす
        epochStartIdx = startIdx + shiftAmount;
        epochEndIdx = epochStartIdx + params.eeg.Fs * params.eeg.windowSize - 1;
        
        % データの範囲チェック
        if epochEndIdx <= size(preprocessedData, 2)
            DataSet{epochIndex} = preprocessedData(:, epochStartIdx:epochEndIdx);
            labels(epochIndex) = stimulusStart(ii, 1);  % ラベルを保存
            epochIndex = epochIndex + 1;
        else
            warning('エポック %d-%d がデータの範囲外です。スキップします。', ii, jj);
        end
    end
end

% 使用されなかったセルを削除
DataSet = DataSet(1:epochIndex-1);
labels = labels(1:epochIndex-1);

% データ拡張
[augmentedData, augmentedLabels] = augmentEEGData(DataSet, labels, params.varargin);

% データの形状を確認
disp(['エポック化されたデータセットの数: ', num2str(length(augmentedData))]);
disp(['各エポックのサイズ: ', num2str(size(augmentedData{1}))]);


% 各ラベルに対応するデータを抽出
uniqueLabels = unique(augmentedLabels);
labelData = cell(length(uniqueLabels), 1);

% データセットをラベルごとに分類
for i = 1:length(uniqueLabels)
    labelData{i} = augmentedData(augmentedLabels == uniqueLabels(i), :);
end

dataClass = cell(length(uniqueLabels), 1);
labelClass = cell(length(uniqueLabels), 1);

for i = 1:length(uniqueLabels)
    dataClass{i} = labelData{uniqueLabels == i};
    labelClass{i,1} = repmat(i, size(dataClass{i}, 1), 1);
end

% データセットを保存
save(params.experiment.datasetName, 'eegData', 'preprocessedData', 'stimulusStart');
disp('データセットが更新されました。');


%% CSPフィルター作成
cspIndex = 1;
[~, ~, cspFilters{cspIndex}] = processCSPData2Class(dataClass{1}, dataClass{2});

% データセットを保存
save(params.experiment.datasetName, 'eegData', 'preprocessedData',  'stimulusStart', 'cspFilters');
disp('データセットが更新されました。');


%% 特徴量抽出
cspFeatures = extractIntegratedCSPFeatures(augmentedData, cspFilters);

save(params.experiment.datasetName, 'eegData', 'preprocessedData',  'stimulusStart', 'cspFilters', 'cspFeatures', 'labels');

%% 特徴分類
X = cspFeatures;
y = augmentedLabels;

classifierLabel = sprintf('Classifier %d-%d', uniqueLabels(1), uniqueLabels(2));
[svmMdl, meanAccuracy] = runSVMAnalysis(X, y, params.model, params.eeg.K, params.model.modelType, params.model.useOptimization, classifierLabel);

save(params.experiment.datasetName, 'eegData', 'preprocessedData', 'stimulusStart', 'cspFilters', 'cspFeatures', 'labels', 'svmMdl');
disp('Data saved successfully.');


%% ボタン構成
function createMovieStartGUI()
    global t csv_file label_name startButton stopButton labelButton csvFilename button1 button2; % グローバル変数に button1 と button2 を追加
    % GUIの作成と設定をここに記述
    fig = figure('Position', [100 100 300 200], 'MenuBar', 'none', 'ToolBar', 'none'); % ウィンドウの高さを増加

    startButton = uicontrol('Style', 'pushbutton', 'String', 'Start', ...
        'Position', [60 140 70 30], 'Callback', @startButtonCallback);

    stopButton = uicontrol('Style', 'pushbutton', 'String', 'Stop', ...
        'Position', [160 140 70 30], 'Callback', @stopButtonCallback, 'Enable', 'off');

    labelButton = uicontrol('Style', 'pushbutton', 'String', 'Label', ...
        'Position', [110 90 70 30], 'Callback', @labelButtonCallback, 'Enable', 'off');

    % 新しいボタンを追加
    button1 = uicontrol('Style', 'pushbutton', 'String', '1', ...
        'Position', [60 40 70 30], 'Callback', @(hObject,eventdata)labelButtonCallback(hObject,eventdata,1), 'Enable', 'off');

    button2 = uicontrol('Style', 'pushbutton', 'String', '2', ...
        'Position', [160 40 70 30], 'Callback', @(hObject,eventdata)labelButtonCallback(hObject,eventdata,2), 'Enable', 'off');

    % 他の初期化コードをここに記述
    label_name = 'stimulus';
    csv_file = fopen(csvFilename, 'w');
    t = timer('TimerFcn', @(hObject, eventdata) timer_callback(hObject, eventdata), 'Period', 0.1, 'ExecutionMode', 'fixedRate');
end

% 脳波データ記録開始ボタン
function startButtonCallback(hObject, eventdata)
    global isRunning t startButton stopButton labelButton button1 button2; % グローバル変数に button1 と button2 を追加

    % 実行中
    disp('データ収集中...指示に従ってください...');
    tic; % タイマーの開始時間を記録
    start(t);
    startButton.Enable = 'off';
    stopButton.Enable = 'on';
    labelButton.Enable = 'on';
    button1.Enable = 'on';
    button2.Enable = 'on'; 
    isRunning = true;
end

% 脳波データ記録停止ボタン
function stopButtonCallback(hObject, eventdata)
    global isRunning t startButton stopButton labelButton button1 button2; % グローバル変数に button1 と button2 を追加

    isRunning = false;
    % ストップボタンのコールバック関数の内容をここに記述
    stop(t);
    startButton.Enable = 'on';
    stopButton.Enable = 'off';
    labelButton.Enable = 'off';
    button1.Enable = 'off'; % 新しいボタンを無効化
    button2.Enable = 'off'; % 新しいボタンを無効化

    % プログラムの終了フラグを更新してGUIを閉じる
    close all;
end

% 動画・再生ボタン
function labelButtonCallback(hObject, eventdata, label)
    global t csv_file csvFilename;
    % label: 'Label'ボタンの場合は未定義，'1'ボタンの場合は1，'2'ボタンの場合は2
    % ラベルボタンのコールバック関数の内容をここに記述
    current_time = toc - t.StartDelay; % 経過時間の計算
    disp(current_time);
    if nargin < 3 % 'Label'ボタンが押された場合
        fprintf(csv_file, '%d,%.3f\n', 3, current_time);
    else % '1'または'2'ボタンが押された場合
        fprintf(csv_file, '%d,%.3f\n', label, current_time);
    end
    fclose(csv_file); % ファイルを閉じる
    csv_file = fopen(csvFilename, 'a'); % ファイルを追記モードで再度開く
end

% タイマー呼び出し中処理
function timer_callback(hObject, eventdata)
    % タイマーコールバック関数の内容をここに記述
end
