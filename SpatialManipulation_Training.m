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


%% データ受信と処理
disp('Now receiving data...');

%% パラメータ設定
global isRunning Fs minf maxf nTrials Ch numFilter filtOrder labelName csvFilename singleTrials  t csv_file
minf = 1;
maxf = 30;
filtOrder = 1500;
isRunning = false;
movieTimes = 4;
overlap = 4;
portNumber = 12354; % UDPポート番号

% データセットの名前を指定
name = 'name'; % ここを変更
datasetName12 = [name '_dataset12'];
datasetName23 = [name '_dataset23'];
datasetName13 = [name '_dataset13'];
dataName = name;
csvFilename = [name '_label.csv'];
labelName = 'stimulus';

% パラメータ設定
params = struct();
params.modelType = 'svm';
params.useOptimization = false;
params.kernelFunctions = {'linear', 'rbf', 'polynomial'};
params.kernelScale = [0.1, 1, 10];
params.boxConstraint = [0.1, 1, 10, 100];

% EPOC X
Fs = 256;
Ch = {'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'}; % チャンネル
selectedChannels = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]; % 'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'
numFilter = 7;
K = 10;

% ラベル作成
label = readmatrix('labels/SpatialAudio_Training.csv');
labelNum = size(label, 1);

% データ数
nTrials = movieTimes * labelNum * overlap;
singleTrials = labelNum * overlap;


%% 脳波データ計測
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
    selectedData = vec(selectedChannels);
    eegData = [eegData selectedData];
    
    if udpSocket.BytesAvailable > 0
        % データを受信
        receivedData = fread(udpSocket, udpSocket.BytesAvailable, 'uint8');
        % 受信データを文字列に変換
        str = char(receivedData');

        % 受信データに応じて処理を行う
        if strcmp(str, 'Start')
            disp('トレーニング開始');
            % ラベルボタンのコールバック関数の内容をここに記述
            current_time = toc - t.StartDelay; % 経過時間の計算
            disp(current_time);
            fprintf(csv_file, '%s,%.3f\n', labelName, current_time);
            fclose(csv_file); % ファイルを閉じる
            csv_file = fopen(csvFilename, 'a'); % ファイルを追記モードで再度開く
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
save(datasetName23, 'eegData');
save(datasetName12, 'eegData');
save(datasetName13, 'eegData');
disp(['データセットが保存されました。']);

% UDPソケットを閉じる
fclose(udpSocket);
delete(udpSocket);
clear udpSocket;

%% 取得した脳波データの前処理
disp('データ解析中...しばらくお待ちください...');

% データの前処理
preprocessedData = preprocessData(eegData, Fs, filtOrder, minf, maxf);

% ラベル作成
label = readmatrix('labels/SpatialAudio_Training.csv');
labels = [];
for ii = 1:labelNum
    for kk = 1:overlap
       labels(overlap*(ii-1)+kk,1) = label(ii,1);
    end
end
labels = repmat(labels, movieTimes, 1);


% エポック化
% セクションで実行した時は，保存していたmovieStart使うようにするため
if ~exist('movieStart', 'var') || isempty(movieStart)
    movieStart = readmatrix(csvFilename);
end
for ii = 1:movieTimes
    % 刺激開始時間
    switch ii
        case 1
            st = movieStart(1,2);
        case 2
            st = movieStart(2,2);
        case 3
            st = movieStart(3,2);
        case 4
            st = movieStart(4,2);
    end
    
    for jj = 1:labelNum
        for kk = 1:length(Ch)
            % 2秒間のデータを抽出
            startIdx = round(Fs*((st+10)+15*(jj-1))) + 1;
            endIdx = startIdx + Fs*2 - 1;

            % エポック
            tt = 0;
            for ll = 1:overlap
                DataSet{singleTrials*(ii-1)+overlap*(jj-1)+ll, 1}(kk,:) = preprocessedData(kk,startIdx+round(tt*Fs):endIdx+round(tt*Fs)); % tt秒後のデータ
                tt = tt + 1;
            end
        end
    end
end


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
dataClass3 = labelData{uniqueLabels == 3};

% ラベルの配列を作成
labelClass1 = repmat(1, size(dataClass1, 1), 1);
labelClass2 = repmat(2, size(dataClass2, 1), 1);
labelClass3 = repmat(3, size(dataClass3, 1), 1);

% データセットを保存
save(datasetName23, 'eegData', 'preprocessedData', 'movieStart');
save(datasetName12, 'eegData', 'preprocessedData', 'movieStart');
save(datasetName13, 'eegData', 'preprocessedData', 'movieStart');
disp(['データセットが更新されました。']);



%% 脳波データ解析
disp('機械学習解析中...しばらくお待ちください...');


%% CSPデータセット作成
% オブジェクト前方移動(2) VS オブジェクト後方移動(3)
[cspClass2, cspClass3, cspFilters23] = processCSPData2Class(dataClass2, dataClass3);
SVMDataSet23 = [cspClass2; cspClass3];
SVMLabels23 = [labelClass2; labelClass3];

% 安静(1) VS オブジェクト前方移動(2)
[cspClass1, cspClass2, cspFilters12] = processCSPData2Class(dataClass1, dataClass2);
SVMDataSet12 = [cspClass1; cspClass2];
SVMLabels12 = [labelClass1; labelClass2];

% 安静(1) VS オブジェクト後方移動(3)
% CSPデータセット
[cspClass1, cspClass3, cspFilters13] = processCSPData2Class(dataClass1, dataClass3);
SVMDataSet13 = [cspClass1; cspClass3];
SVMLabels13 = [labelClass1; labelClass3];

% データセットを保存
save(datasetName23, 'eegData', 'preprocessedData',  'movieStart', 'SVMDataSet23', 'SVMLabels23', 'cspFilters23');
save(datasetName12, 'eegData', 'preprocessedData',  'movieStart', 'SVMDataSet12', 'SVMLabels12', 'cspFilters12');
save(datasetName13, 'eegData', 'preprocessedData',  'movieStart', 'SVMDataSet13', 'SVMLabels13', 'cspFilters13');
disp(['データセットが更新されました。']);


%% 分類器作成
X23 = SVMDataSet23;
y23 = SVMLabels23;
X12 = SVMDataSet12;
y12 = SVMLabels12;
X13 = SVMDataSet13;
y13 = SVMLabels13;

svmMdl23 = runSVMAnalysis(X23, y23, params, K, params.modelType, params.useOptimization, 'Classifier 2-3');
svmMdl12 = runSVMAnalysis(X12, y12, params, K, params.modelType, params.useOptimization, 'Classifier 1-2');
svmMdl13 = runSVMAnalysis(X13, y13, params, K, params.modelType, params.useOptimization, 'Classifier 1-3');

% データセットを保存
save(datasetName23, 'eegData', 'preprocessedData',  'movieStart', 'SVMDataSet23', 'SVMLabels23', 'cspFilters23', 'svmMdl23');
save(datasetName12, 'eegData', 'preprocessedData',  'movieStart', 'SVMDataSet12', 'SVMLabels12', 'cspFilters12', 'svmMdl12');
save(datasetName13, 'eegData', 'preprocessedData',  'movieStart', 'SVMDataSet13', 'SVMLabels13', 'cspFilters13', 'svmMdl13');
disp(['データセットが保存されました。']);


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
    global t csv_file labelName csvFilename; % グローバル変数の宣言
    % ラベルボタンのコールバック関数の内容をここに記述
    current_time = toc - t.StartDelay; % 経過時間の計算
    disp(current_time);
    fprintf(csv_file, '%s,%.3f\n', labelName, current_time);
    fclose(csv_file); % ファイルを閉じる
    csv_file = fopen(csvFilename, 'a'); % ファイルを追記モードで再度開く
end

% タイマー呼び出し中処理
function timer_callback(hObject, eventdata)

end