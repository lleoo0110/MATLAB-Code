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
    'overlap', 1, ...
    'windowSize', 2, ...
    'numFilter', 7, ...
    'K', 5 ...
);

% 名前設定パラメータ
params.experiment = struct(...
    'name', 'reona' ... % ここを変更
);
params.experiment.datasetName = [params.experiment.name '_dataset'];
params.experiment.dataName = params.experiment.name;
params.experiment.csvFilename = [params.experiment.name '_label.csv'];

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

% UDPソケットを作成
udpSocket = udp('127.0.0.1', 'LocalPort', params.experiment.portNumber);
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


%% CSPフィルター作成
cspIndex = 1;
[~, ~, cspFilters{cspIndex}] = processCSPData2Class(dataClass{1}, dataClass{2});

% データセットを保存
save(params.experiment.datasetName, 'eegData', 'preprocessedData',  'stimulusStart', 'cspFilters');
disp('データセットが更新されました。');


%% 特徴量抽出
% CSPフィルタの数（クラスの組み合わせ数）
numCSPFilters = length(cspFilters);

% 特徴量の次元数（各CSPフィルタから抽出する特徴量の数）
numFeaturesPerFilter = size(cspFilters{1}, 2);

% 統合された特徴量行列の初期化
totalEpochs = length(DataSet);
cspFeatures = zeros(totalEpochs, numCSPFilters * numFeaturesPerFilter);

% 各エポックに対してCSPフィルタを適用し，特徴量を抽出
for i = 1:totalEpochs
    epoch = DataSet{i};
    
    featureIndex = 1;
    for j = 1:numCSPFilters
        cspFilter = cspFilters{j};
        features = extractCSPFeatures(epoch, cspFilter);
        
        startIdx = (j-1) * numFeaturesPerFilter + 1;
        endIdx = j * numFeaturesPerFilter;
        cspFeatures(i, startIdx:endIdx) = features;
    end
end

save(params.experiment.datasetName, 'eegData', 'preprocessedData',  'stimulusStart', 'cspFilters', 'cspFeatures', 'labels');

%% 特徴分類
X = cspFeatures;
y = labels;

classifierLabel = sprintf('Classifier %d-%d', uniqueLabels(1), uniqueLabels(2));
[svmMdl, meanAccuracy] = runSVMAnalysis(X, y, params.model, params.eeg.K, params.model.modelType, params.model.useOptimization, classifierLabel);

save(params.experiment.datasetName, 'eegData', 'preprocessedData', 'stimulusStart', 'cspFilters', 'cspFeatures', 'labels', 'svmMdl');
disp('Data saved successfully.');


%% ボタン構成
function createMovieStartGUI()
    global t csv_file label_name startButton stopButton labelButton csvFilename button1 button2; % グローバル変数に button1 と button2 を追加
    % GUIの作成と設定をここに記述
    fig = figure('Position', [100 100 300 250], 'MenuBar', 'none', 'ToolBar', 'none'); % ウィンドウの高さを増加

    startButton = uicontrol('Style', 'pushbutton', 'String', 'Start', ...
        'Position', [50 200 70 30], 'Callback', @startButtonCallback);

    stopButton = uicontrol('Style', 'pushbutton', 'String', 'Stop', ...
        'Position', [150 200 70 30], 'Callback', @stopButtonCallback, 'Enable', 'off');

    labelButton = uicontrol('Style', 'pushbutton', 'String', 'Label', ...
        'Position', [100 150 70 30], 'Callback', @labelButtonCallback, 'Enable', 'off');

    % 新しいボタンを追加
    button1 = uicontrol('Style', 'pushbutton', 'String', '1', ...
        'Position', [50 100 70 30], 'Callback', @(hObject,eventdata)labelButtonCallback(hObject,eventdata,1), 'Enable', 'off');

    button2 = uicontrol('Style', 'pushbutton', 'String', '2', ...
        'Position', [150 100 70 30], 'Callback', @(hObject,eventdata)labelButtonCallback(hObject,eventdata,2), 'Enable', 'off');

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
        fprintf(csv_file, '%d,%.3f\n', 0, current_time);
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
