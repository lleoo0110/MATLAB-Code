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
global isRunning Ch numFilter csvFilename  csvFilename2
minf = 1;
maxf = 30;
Fs = 256;
filtOrder = getOptimalFilterOrder(Fs, minf, maxf);
isRunning = false;
overlap = 4;
windowSize = 2; % データ抽出時間窓
portNumber = 12354; % UDPポート番号
numFilter = 7;
K = 10;

% データセットの名前を指定
name = 'name'; % ここを変更
datasetName = [name '_dataset'];
dataName = name;
csvFilename = [name '_label.csv'];
csvFilename2 = [name '_labelWithFeedback.csv'];

% SVMパラメータ設定
params = struct();
params.modelType = 'ecoc'; % 'svm' or 'ecoc'
params.useOptimization = false;
params.kernelFunctions = {'linear', 'rbf', 'polynomial'};
params.kernelScale = [0.1, 1, 10];
params.boxConstraint = [0.1, 1, 10, 100];

% EPOC X
Ch = {'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'}; % チャンネル
selectedChannels = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]; % 'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'


%% 脳波データ計測
disp('データ計測中...');

% GUIの作成と表示
createMovieStartGUI();

% データ初期化
eegData = [];
preprocessedData = [];
labels = [];
movieStart = [];

% UDPソケットを作成
udpSocket = udp('127.0.0.1', 'LocalPort', portNumber);
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
        if strcmp(str, 'Forward')
            disp('Forward Start');
            labelButtonCallback(2);
        elseif strcmp(str, 'Backward')
            disp('Backward Start');
            labelButtonCallback(3);
        elseif strcmp(str, 'ForwardWithFeedback')
            disp('Forward Start');
            labelButtonCallbackWithFeedback(2);
        elseif strcmp(str, 'BackwardWithFeedback')
            disp('Backward Start');
            labelButtonCallbackWithFeedback(3);
        else
            disp(['Unknown command received: ', str]);
        end
    end
    
    elapsedTime = toc(lastSaveTime);
    if elapsedTime >= saveInterval
        disp('60秒保存');
        % データをファイルに保存
        save(sprintf('%s_data_%d.mat', dataName, fileIndex), 'eegData');
        eegData = []; % メモリから削除
        lastSaveTime = tic;
        fileIndex = fileIndex + 1; % 連番を増加
    end

    pause(0.0001); % 応答性を保つための短い休止
end

% 最後の未保存データを保存
if ~isempty(eegData)
    elapsedTime = toc(lastSaveTime);
    save(sprintf('%s_data_%d.mat', dataName, fileIndex), 'eegData');
end

savedData = [];
fileIndex = 1;
while true
    filename = sprintf('%s_data_%d.mat', dataName, fileIndex);
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
save(datasetName, 'eegData');
disp('データセットが保存されました。');

% UDPソケットを閉じる
fclose(udpSocket);
delete(udpSocket);
clear udpSocket;


%% 取得した脳波データの前処理
disp('データ解析中...しばらくお待ちください...');

% データの前処理
preprocessedData = preprocessData(eegData(selectedChannels, :), Fs, filtOrder, minf, maxf);

% エポック化
% セクションで実行した時は，保存していたstimulusStart使うようにするため
if ~exist('stimulusStart', 'var') || isempty(stimulusStart)
    stimulusStart = readmatrix(csvFilename);
end

% データセットの初期化
nTrials = size(stimulusStart, 1);
totalEpochs = nTrials * overlap;
dataSet = cell(totalEpochs, 1);
labels = zeros(totalEpochs, 1);

epochIndex = 1;
for ii = 1:nTrials
    startIdx = round(Fs * stimulusStart(ii, 2)) + 1;
    endIdx = startIdx + Fs * windowSize - 1;
    
    % エポック化
    for jj = 1:overlap
        shiftAmount = round((jj - 1) * Fs * 1);  % 1秒ずつ時間窓をずらす
        epochStartIdx = startIdx + shiftAmount;
        epochEndIdx = epochStartIdx + Fs * windowSize - 1;
        
        % データの範囲チェック
        if epochEndIdx <= size(preprocessedData, 2)
            dataSet{epochIndex} = preprocessedData(:, epochStartIdx:epochEndIdx);
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


% データセットを分割
% ラベルの一覧を取得
uniqueLabels = unique(labels);

% 各ラベルに対応するデータを抽出して格納するためのセル配列
labelData = cell(length(uniqueLabels), 1);

% 各ラベルに対応するデータを抽出
for i = 1:length(uniqueLabels)
    labelData{i} = DataSet(labels == uniqueLabels(i), :);
end
dataClass1 = labelData{uniqueLabels == 1};
dataClass2 = labelData{uniqueLabels == 2};

% データセットを保存
save(datasetName, 'eegData', 'preprocessedData', 'stimulusStart');
disp('データセットが更新されました。');



%% 脳波データ解析
disp('機械学習解析中...しばらくお待ちください...');


%% CSPデータセット作成
[cspClass1, cspClass2, cspFilters] = processCSPData2Class(dataClass1, dataClass2);
SVMDataSet = [cspClass1; cspClass2];
SVMLabels = [labelClass1; labelClass2];

% データセットを保存
save(datasetName, 'eegData', 'preprocessedData',  'stimulusStart', 'SVMDataSet', 'SVMLabels', 'cspFilters');
disp('データセットが更新されました。');


%% 分類器作成
X = SVMDataSet;
[X, features_mean, features_std] = normalizeFeatures(X);
y = SVMLabels;

svmMdl = runSVMAnalysis(X, y, params, K, params.modelType, params.useOptimization, 'Classifier 1-2');

% データセットを保存
save(datasetName, 'eegData', 'preprocessedData',  'stimulusStart', 'SVMDataSet', 'SVMLabels', 'cspFilters', 'svmMdl');
disp('データセットが保存されました。');


%% ボタン構成
function createMovieStartGUI()
    global t csv_file csv_file2 startButton stopButton labelButton csvFilename csvFilename2;
    % GUIの作成と設定をここに記述
    fig = figure('Position', [100 100 300 200], 'MenuBar', 'none', 'ToolBar', 'none');
    
    startButton = uicontrol('Style', 'pushbutton', 'String', 'Start', ...
        'Position', [50 100 70 30], 'Callback', @startButtonCallback);
    
    stopButton = uicontrol('Style', 'pushbutton', 'String', 'Stop', ...
        'Position', [150 100 70 30], 'Callback', @stopButtonCallback, 'Enable', 'off');
    
    labelButton = uicontrol('Style', 'pushbutton', 'String', 'Label', ...
        'Position', [100 50 70 30], 'Callback', @labelButtonCallback, 'Enable', 'off');
    
    % 他の初期化コードをここに記述
    csv_file = fopen(csvFilename, 'w');
    csv_file2 = fopen(csvFilename2, 'w');
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
function labelButtonCallback(label)
    global t csv_file csvFilename markerData; 
    % ラベルボタンのコールバック関数の内容をここに記述
    current_time = toc - t.StartDelay; % 経過時間の計算
    disp(current_time);
    fprintf(csv_file, '%s,%.3f\n', label, current_time);
    fclose(csv_file); % ファイルを閉じる
    csv_file = fopen(csvFilename, 'a'); % ファイルを追記モードで再度開く
    
    % マーカー送信
%     outlet.push_sample(markerData);
%     disp('Send marker has value: ');
end

function labelButtonCallbackWithFeedback(label)
    global t csv_file2 csvFilename2 markerData; 
    % ラベルボタンのコールバック関数の内容をここに記述
    current_time = toc - t.StartDelay; % 経過時間の計算
    disp(current_time);
    fprintf(csv_file2, '%s,%.3f\n', label, current_time);
    fclose(csv_file2); % ファイルを閉じる
    csv_file2 = fopen(csvFilename2, 'a'); % ファイルを追記モードで再度開く
    
    % マーカー送信
%     outlet.push_sample(markerData);
%     disp('Send marker has value: ');
end

% タイマー呼び出し中処理
function timer_callback(hObject, eventdata)

end