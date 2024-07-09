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


%%  パラメータ設定
global isRunning Ch numFilter csvFilename
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
% stimulusStart = stimulusWithFeedbackStart; % 音声フィードバック有無切り替え

% データセットの名前を指定
name = 'testl'; % ここを変更
datasetName = [name '_dataset'];
dataName = name;
csvFilename = [name '_label.csv'];

% SVMパラメータ設定
params = struct();
params.modelType = 'svm'; % 'svm' or 'ecoc'
params.useOptimization = false;
params.kernelFunctions = {'linear', 'rbf', 'polynomial'};
params.kernelScale = [0.1, 1, 10];
params.boxConstraint = [0.1, 1, 10, 100];

% EPOC X
Ch = {'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'}; % チャンネル
selectedChannels = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]; % 'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'


%% 脳波データ計測
% GUIの作成と表
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

% 取得した脳波データから解析
disp('データ解析中...しばらくお待ちください...');


%%  データの前処理
preprocessedData = preprocessData(eegData, filtOrder, minf, maxf);

% エポック化
movieStart = readmatrix(csvFilename);
for ii = 1:movieTimes
    % 刺激開始時間
    switch ii
        case 1
        st = movieStart(1,2);
        case 2
        st = movieStart(2,2);
    end
    
    for jj = 1:labelNum
        for kk = 1:length(Ch)
            % 2秒間のデータを抽出
            startIdx = round(Fs*((st+5)+10*(jj-1))) + 1;
            endIdx = startIdx + Fs*2 - 1;

            % データ数増加
            tt = 0;
            for ll = 1:overlap
                DataSet{singleTrials*(ii-1)+overlap*(jj-1)+ll, 1}(kk,:) = preprocessedData(kk,startIdx+round(tt*Fs):endIdx+round(tt*Fs)); % tt秒後のデータ
                tt = tt + 1;
            end
        end
    end
end


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
%  ...

% ラベルの配列を作成
labelClass1 = repmat(1, size(dataClass1, 1), 1);
labelClass2 = repmat(2, size(dataClass2, 1), 1);
labelClass3 = repmat(3, size(dataClass3, 1), 1);
% ...

%% データ保存
save(datasetName, 'eegData', 'preprocessedData ', 'dataClass', 'movieStart');
disp('データ解析完了しました');


%% 脳波データ解析
% 全組み合わせの分類精度算出
accuracyMatrix = zeros(6, 6);
% 全てのクラスの組み合わせについてループ
for i = 1:6
    for j = i+1:6
        % クラスデータとラベルを取得
        dataClassA = eval(['dataClass', num2str(i)]);
        dataClassB = eval(['dataClass', num2str(j)]);
        labelClassA = repmat(1, size(dataClassA, 1), 1);
        labelClassB = repmat(2, size(dataClassB, 1), 1);
        
        % CSP特徴抽出
        [cspClassA, cspClassB, cspFiltersAB] = processCSPData2Class(dataClassA, dataClassB);
        SVMDataSet = [cspClassA; cspClassB];
        SVMLabels = [labelClassA; labelClassB];
        
        % SVMモデルの学習
        X = SVMDataSet;
        [X, features_mean, features_std] = normalizeFeatures(X);
        y = SVMLabels;

        % 分類器作成
        svmMdl = runSVMAnalysis(X, y, params, K, params.modelType, params.useOptimization, 'Classifier 1-2');
        
        % 交差検証
        CVSVMModel = crossval(svmMdl, 'KFold', K); 
        loss = kfoldLoss(CVSVMModel);
        meanAccuracy = 1 - loss;
        
        % 分類精度を行列に保存
        accuracyMatrix(i, j) = meanAccuracy;
        accuracyMatrix(j, i) = meanAccuracy;
        
        % 分類精度を表示
        disp(['Class ', num2str(i), ' vs Class ', num2str(j), ': ', num2str(meanAccuracy * 100), '%']);
        close('all');
    end
end

% 分類精度行列を表示
disp('Accuracy Matrix:');
disp(accuracyMatrix);



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