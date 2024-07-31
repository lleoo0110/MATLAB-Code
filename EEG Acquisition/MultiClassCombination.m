%% データ受信
% ライブラリーの初期化
try
    lib = lsl_loadlib(env_translatepath('dependencies:/liblsl-Matlab/bin'));
catch
    lib = lsl_loadlib();
end

% resolve a stream...
disp('Resolving an EEG stream...');
result = {};
while isempty(result)
    streamName = 'EmotivDataStream-EEG'; % name of stream. the name is one of vale EmotivDataStream-Motion,
                                         % EmotivDataStream-EEG , 'EmotivDataStream-Performance Metrics'
    result = lsl_resolve_byprop(lib,'name', streamName); 
end

% create a new inlet
disp('Opening an inlet...');
inlet = lsl_inlet(result{1});

% get the full stream info (including custom meta-data) and dissect it
inf = inlet.info();
fprintf('The stream''s XML meta-data is: \n');
fprintf([inf.as_xml() '\n']);
fprintf(['The manufacturer is: ' inf.desc().child_value('manufacturer') '\n']);
fprintf('The channel labels are as follows:\n');
ch = inf.desc().child('channels').child('channel');
for k = 1:inf.channel_count()
    fprintf(['  ' ch.child_value('label') '\n']);
    ch = ch.next_sibling();
end


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
    'overlap', 4, ...
    'windowSize', 2, ...
    'numFilter', 7, ...
    'K', 5 ...
);

% 動画刺激パラメータ
params.stim = struct(...
    'videoDuration', 5 * 60, ... % 動画の全体長（秒）
    'initialDelay', 5, ... % 動画開始から最初の刺激までの遅延（秒）
    'cycleDuration', 10, ... % 1サイクルの長さ（秒）
    'labelName', 'Experiment_Shiori', ...
    'portNumber', 12345 ...
);

% 名前設定パラメータ
params.experiment = struct(...
    'name', 'test' ... % ここを変更
);
params.experiment.datasetName = [params.experiment.name '_dataset'];
params.experiment.dataName = params.experiment.name;
params.experiment.csvFilename = [params.experiment.name '_label.csv'];

% SVMパラメータ設定
params.model = struct(...
    'modelType', 'ecoc', ... % 'svm' or 'ecoc'
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

% UDPソケットを作成
udpSocket = udp('127.0.0.1', 'LocalPort', params.stim.portNumber);
% 受信データがある場合に処理を行う    
fopen(udpSocket);

while ~isRunning
    % 待機時間
    pause(0.1);
end

% LSLバッファのクリア
while ~isempty(inlet.pull_sample(0)) % 0秒のタイムアウトでpull_sampleを呼び出し、バッファが空になるまで繰り返す
end

% EEGデータ収集
saveInterval = 60; % 保存間隔（秒）
fileIndex = 1;
lastSaveTime = tic;
while isRunning
    [vec, ts] = inlet.pull_sample(); % データの受信
    vec = vec(:); % 1x19の行ベクトルを19x1の列ベクトルに変換
    eegData = [eegData vec];
    
    if udpSocket.BytesAvailable > 0
        % データを受信
        receivedData = fread(udpSocket, udpSocket.BytesAvailable, 'uint8');
        % 受信データを文字列に変換
        str = char(receivedData');

        % 受信データに応じて処理を行う
        if strcmp(str, 'MovieStart')
            disp('Movie Start');
            labelButtonCallback(0);
        else
            disp(['Unknown command received: ', str]);
        end
    end
    
    elapsedTime = toc(lastSaveTime);
    if elapsedTime >= saveInterval
        disp('60秒保存');
        % データをファイルに保存
        save(sprintf('%s_data_%d.mat', params.experiment.dataName, fileIndex), 'eegData');
        eegData = []; % メモリから削除
        lastSaveTime = tic;
        fileIndex = fileIndex + 1; % 連番を増加
    end

    pause(0.0001); % 応答性を保つための短い休止
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

% UDPソケットを閉じる
fclose(udpSocket);
delete(udpSocket);
clear udpSocket;


%% 脳波データの前処理
disp('データ解析中...しばらくお待ちください...');

% データの前処理
preprocessedData = preprocessData(eegData(params.epocx.selectedChannels, :), params.eeg.Fs, params.eeg.filtOrder, params.eeg.minf, params.eeg.maxf);

% ラベル作成
if ~exist('stimulusStart', 'var') || isempty(stimulusStart)
    % CSVファイルからデータを読み込む
    videoStarts = readmatrix(csvFilename);
    labels = readmatrix(params.stim.labelName);

    % videoStartsの2列目（時間データ）のみを抽出
    videoStarts = videoStarts(:, 2);

    % 各動画の刺激回数を計算
    stimulusVideo = floor(params.stim.videoDuration / params.stim.cycleDuration);

    % 刺激開始タイミングを格納する配列を初期化
    stimulusStart = [];

    % 各動画に対して処理を行う
    for i = 1:length(videoStarts)
        videoStart = videoStarts(i);

        % 現在の動画の刺激タイミングとラベルを計算
        for j = 1:stimulusVideo
            current_time = videoStart + params.stim.initialDelay + (j-1) * params.stim.cycleDuration;
            label = labels(mod(j-1, length(labels)) + 1);
            stimulusStart = [stimulusStart; label, current_time];
        end
    end
end

% エポック化
% データセットの初期化
nTrials = size(stimulusStart, 1);
totalEpochs = nTrials * params.eeg.overlap;
DataSet = cell(totalEpochs, 1);
labels = zeros(totalEpochs, 1);

epochIndex = 1;
for ii = 1:nTrials
    startIdx = round(params.eeg.Fs * stimulusStart(ii, 2)) + 1;
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

% データの形状を確認
disp(['エポック化されたデータセットの数: ', num2str(length(DataSet))]);
disp(['各エポックのサイズ: ', num2str(size(DataSet{1}))]);


% 各ラベルに対応するデータを抽出
uniqueLabels = unique(labels);
labelData = cell(length(uniqueLabels), 1);

% データセットをラベルごとに分類
for i = 1:length(uniqueLabels)
    labelData{i} = DataSet(labels == uniqueLabels(i), :);
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


%% 脳波データ解析
% 全組み合わせの分類精度算出
accuracyMatrix = zeros(length(uniqueLabels), length(uniqueLabels));
for i = 1:(length(uniqueLabels))
    for j = i+1:(length(uniqueLabels))
        dataClassA = dataClass{i};
        dataClassB = dataClass{j};
        labelClassA = labelClass{i};
        labelClassB = labelClass{j};
                
        % CSP特徴抽出
        [cspClassA, cspClassB, ~] = processCSPData2Class(dataClassA, dataClassB);
        allCSPFeatures = [cspClassA; cspClassB];
        allLabels = [labelClassA; labelClassB];
                
        % 機械学習部分
        X = allCSPFeatures;
        y = allLabels;
        
        classifierLabel = sprintf('Classifier %d-%d', uniqueLabels(i), uniqueLabels(j));
        [~, meanAccuracy] = runSVMAnalysis(X, y, params.model, params.eeg.K, params.model.modelType, params.model.useOptimization, classifierLabel);
    
        accuracyMatrix(i, j) = meanAccuracy;
        accuracyMatrix(j, i) = meanAccuracy;
        
        close('all');
    end
end

disp('Accuracy Matrix:');
disp(accuracyMatrix);

save(params.experiment.datasetName, 'eegData', 'preprocessedData', 'stimulusStart', 'accuracyMatrix');
disp('Data saved successfully.');


%% ボタン構成
function createMovieStartGUI()
    global t csv_file label_name startButton stopButton labelButton csvFilename; % グローバル変数の宣言
    % GUIの作成と設定をここに記述
    fig = figure('Position', [100 100 300 200], 'MenuBar', 'none', 'ToolBar', 'none');
    
    startButton = uicontrol('Style', 'pushbutton', 'String', 'Start', ...
        'Position', [50 100 70 30], 'Callback', @startButtonCallback);
    
    stopButton = uicontrol('Style', 'pushbutton', 'String', 'Stop', ...
        'Position', [150 100 70 30], 'Callback', @stopButtonCallback, 'Enable', 'off');
    
    labelButton = uicontrol('Style', 'pushbutton', 'String', 'Label', ...
        'Position', [100 50 70 30], 'Callback', @labelButtonCallback, 'Enable', 'off');
    
    % 他の初期化コードをここに記述
    label_name = 'stimulus';
    csv_file = fopen(csvFilename, 'w');
    t = timer('TimerFcn', @(hObject, eventdata) timer_callback(hObject, eventdata), 'Period', 0.1, 'ExecutionMode', 'fixedRate');
end

% 脳波データ記録開始ボタン
function startButtonCallback(hObject, eventdata)
    global isRunning t startButton stopButton labelButton; % グローバル変数の宣言
    
    % 実行中
    disp('データ収集中...指示に従ってください...');
    tic; % タイマーの開始時間を記録
    start(t);
    startButton.Enable = 'off';
    stopButton.Enable = 'on';
    labelButton.Enable = 'on';
    isRunning = true;
end

% 脳波データ記録停止ボタン
function stopButtonCallback(hObject, eventdata)
    global isRunning t startButton stopButton labelButton; % グローバル変数の宣言
    
    isRunning = false;
    % ストップボタンのコールバック関数の内容をここに記述
    stop(t);
    startButton.Enable = 'on';
    stopButton.Enable = 'off';
    labelButton.Enable = 'off';

    % プログラムの終了フラグを更新してGUIを閉じる
    close all;
end

% 動画・再生ボタン
function labelButtonCallback(hObject, eventdata)
    global t csv_file csvFilename; % グローバル変数の宣言
    % ラベルボタンのコールバック関数の内容をここに記述
    current_time = toc - t.StartDelay; % 経過時間の計算
    disp(current_time);
    label = 0;
    fprintf(csv_file, '%d,%.3f\n', label, current_time);
    fclose(csv_file); % ファイルを閉じる
    csv_file = fopen(csvFilename, 'a'); % ファイルを追記モードで再度開く
end

% タイマー呼び出し中処理
function timer_callback(hObject, eventdata)

end