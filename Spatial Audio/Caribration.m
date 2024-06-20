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


% データ受信と処理
addpath '/Users/lleoo/Documents/大学授業/研究/BCIxD/Experiment/labels'
addpath '/Users/lleoo/Documents/MATLAB Repogitory/emotiv-lsl_2020b'
addpath '/Users/lleoo/Documents/MATLAB Repogitory/program/Experiment'

disp('Now receiving data...');
global isRunning Fs minf maxf nTrials Ch numFilter filtOrder labelName csvFilename singleTrials  t csv_file
minf = 8;
maxf = 30;
filtOrder = 400;
isRunning = false;
movieTimes = 4;
labelNum = 20;
overlap = 3;
nTrials = movieTimes * labelNum * overlap;
singleTrials = labelNum * overlap;
datasetName12 = 'shohei_dataset12'; % データセットの名前を指定
datasetName23 = 'shohei_dataset23';
datasetName13 = 'shohei_dataset13';
dataName = 'shohei';
csvFilename = 'shohei_label.csv';
labelName = 'stimulus';

% UDPポート番号
portNumber = 12354;
% UDPソケットを作成
udpSocket = udp('127.0.0.1', 'LocalPort', portNumber);
% 受信データがある場合に処理を行う    
fopen(udpSocket);

% EPOC X
Fs = 256;
Ch = {'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'}; % チャンネル
selectedChannels = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]; % 'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'
numFilter = 4;

% グリッドリサーチ パラメータの範囲を定義
kernelFunctions = {'linear', 'rbf', 'polynomial'};
kernelScale = [0.1, 1, 10];
boxConstraint = [0.1, 1, 100];

% GUIの作成と表示
createMovieStartGUI();

eegData = [];
preprocessedData = [];
labels = [];

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
eegData = savedData;

% UDPソケットを閉じる
fclose(udpSocket);
delete(udpSocket);
clear udpSocket;

% 取得した脳波データから解析
disp('データ解析中...しばらくお待ちください...');


% データの前処理
preprocessedData = preprocessData(eegData, filtOrder, minf, maxf);


% ラベル作成
label = readmatrix('labels/Experiment_label.csv');
labels = [];
for ii = 1:labelNum
    for kk = 1:overlap
       labels(overlap*(ii-1)+kk,1) = label(ii,1);
    end
end
labels = repmat(labels, movieTimes, 1);

% エポック化
movieStart = readmatrix(csvFilename);
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
            startIdx = round(Fs*((st+11)+15*(jj-1))) + 1;
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
dataClass4 = labelData{uniqueLabels == 4};

% ラベルの配列を作成
labelClass1 = repmat(1, size(dataClass1, 1), 1);
labelClass2 = repmat(2, size(dataClass2, 1), 1);
labelClass3 = repmat(3, size(dataClass3, 1), 1);
labelClass4 = repmat(4, size(dataClass4, 1), 1);

% オブジェクト前進 VS オブジェクト後退
% CSPデータセット
[cspClass2, cspClass3, cspFilters23] = processCSPData2Class(dataClass2, dataClass3);
SVMDataSet23 = [cspClass2; cspClass3];
SVMLabels23 = [labelClass2; labelClass3];

% 分類精度計算
meanAccuracy23 = zeros(1, 1);
% データ
X = SVMDataSet23;
y = SVMLabels23;

% SVMモデルの訓練
t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto');
svmMdl23 = fitcecoc(X, y, 'Learners', t);

% クロスバリデーション
CVSVMModel23 = crossval(svmMdl23, 'KFold', 5); % Kは分割数
% クロスバリデーションによる平均分類誤差の計算
loss = kfoldLoss(CVSVMModel23);
meanAccuracy23 = 1-loss;

disp(['Accuracy23', '：', num2str(meanAccuracy23 * 100), '%']);


% データセットを保存
save(datasetName23, 'eegData', 'preprocessedData', 'SVMDataSet23', 'SVMLabels23', 'cspFilters23', 'svmMdl23');
disp(['データセットが ', datasetName23, ' として保存されました。']);
disp('データ解析完了しました');



% 安静 VS オブジェクト前進
% CSPデータセット
[cspClass1, cspClass2, cspFilters12] = processCSPData2Class(dataClass1, dataClass2);
SVMDataSet12 = [cspClass1; cspClass2];
SVMLabels12 = [labelClass1; labelClass2];

% 分類精度計算
meanAccuracy12 = zeros(1, 1);
% データ
X = SVMDataSet12;
y = SVMLabels12;

% SVMモデルの訓練
t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto');
svmMdl12 = fitcecoc(X, y, 'Learners', t);

% クロスバリデーション
CVSVMModel12 = crossval(svmMdl12, 'KFold', 5); % Kは分割数
% クロスバリデーションによる平均分類誤差の計算
loss = kfoldLoss(CVSVMModel12);
meanAccuracy12 = 1-loss;

disp(['Accuracy12', '：', num2str(meanAccuracy12 * 100), '%']);


% データセットを保存
save(datasetName12, 'eegData', 'preprocessedData', 'SVMDataSet12', 'SVMLabels12', 'cspFilters12', 'svmMdl12');
disp(['データセットが ', datasetName12, ' として保存されました。']);
disp('データ解析完了しました');


% 安静 VS オブジェクト後退
% CSPデータセット
[cspClass1, cspClass3, cspFilters13] = processCSPData2Class(dataClass1, dataClass3);
SVMDataSet13 = [cspClass1; cspClass3];
SVMLabels13 = [labelClass1; labelClass3];

% 分類精度計算
meanAccuracy13 = zeros(1, 1);
% データ
X = SVMDataSet13;
y = SVMLabels13;

% SVMモデルの訓練
t = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto');
svmMdl13 = fitcecoc(X, y, 'Learners', t);

% クロスバリデーション
CVSVMModel13 = crossval(svmMdl13, 'KFold', 5); % Kは分割数
% クロスバリデーションによる平均分類誤差の計算
loss = kfoldLoss(CVSVMModel13);
meanAccuracy13 = 1-loss;

disp(['Accuracy13', '：', num2str(meanAccuracy13 * 100), '%']);


% データセットを保存
save(datasetName13, 'eegData', 'preprocessedData', 'SVMDataSet13', 'SVMLabels13', 'cspFilters13', 'svmMdl13');
disp(['データセットが ', datasetName13, ' として保存されました。']);
disp('データ解析完了しました');

% ボタン構成
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