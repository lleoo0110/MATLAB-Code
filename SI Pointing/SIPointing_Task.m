%% パスの追加
mfilepath=fileparts(which(mfilename));
addpath(fullfile(mfilepath,'./liblsl-Matlab'));

if ismac
    % Code to run on Mac platform
    addpath(fullfile(mfilepath,'./bin/mac'));
    addpath(fullfile(mfilepath,'./liblsl-Matlab'));
elseif isunix
    % Code to run on Linux platform
    addpath(fullfile(mfilepath,'./bin/linux'));
elseif ispc
    % Code to run on Windows platform
    addpath(fullfile(mfilepath,'./bin/win64'));
else
    disp('Platform not supported');
end

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


%%  データ受信と処理
disp('Now receiving data...');

%% パラメータ設定
global Fs minf maxf filtOrder numFilter isRunning
minf = 1;
maxf = 40;
filtOrder = 400;
threshold = 0.4; % 閾値の設定

% EPOC X
Fs = 256;
Ch = {'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'}; % チャンネル
selectedChannels = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]; % 'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'
numFilter = 7;

% MN8
% Fs = 128;
% Ch = {'T7','T8'};
% selectedChannels = [4, 5]; % T7, T8のデータを選択

windowSize = 10; % ウィンドウサイズ（秒）
stepSize = 0.1; % ステップサイズ（秒）
samplesPerWindow = windowSize * Fs; % ウィンドウ内のサンプル数
stepSamples = stepSize * Fs; % ステップサイズに相当するサンプル数
dataBuffer = []; % データバッファの初期化

% クラスラベルの確認
classNames = svmProbModel.ClassNames;
positiveClassIndex = find(classNames == 1);  % 正のクラス（例: 安静状態）のインデックス

%% GUIの作成と表示
isRunning = true;
createSaveDataGUI();


%% 脳波データ計測
while isRunning
    [vec, ts] = inlet.pull_sample(); % データの受信
    vec = vec(:); % 1x19の行ベクトルを19x1の列ベクトルに変換
    selectedData = vec(selectedChannels);
    
    % データバッファの更新（チャンネルごとにデータを追加）
    if isempty(dataBuffer)
        dataBuffer = selectedData; % 最初のデータセットの場合
    else
        dataBuffer = [dataBuffer selectedData]; % データを追加
    end
    
    if size(dataBuffer, 2) >= samplesPerWindow        
        preprocessedData = preprocessData(dataBuffer(:, 1:samplesPerWindow), filtOrder, minf, maxf); % データの前処理
        analysisData = preprocessedData(:, end-Fs*1+1:end);
        
        % 特徴量抽出
        features = extractCSPFeatures(analysisData, cspFilters);
        features = features';
        
        % SVMモデルから予想を出力
        [preLabel, preScore] = predict(svmProbModel, features);
        
        % 閾値による決定
        if preScore(positiveClassIndex) >= threshold
            svmOutput = 1;  % 正のクラス（安静状態）
        else
            svmOutput = 2;  % 負のクラス（発話イメージ状態）
        end
        
        % Unityへのデータ通信
        SendData(svmOutput);
        disp(svmOutput);

        % データバッファの更新
        dataBuffer = dataBuffer(:, (stepSamples+1):end); % オーバーラップを保持
    end
    
    pause(0.0001);  % 応答性を保つための短い休止
end


%% ボタン
function createSaveDataGUI()
    % GUIの作成
    fig = uifigure('Name', '脳波データ保存', 'Position', [100 100 300 150]);
    % 保存ボタンの作成
    btnSave = uibutton(fig, 'push', 'Text', '終了', ...
                       'Position', [75, 55, 150, 40], ...
                       'ButtonPushedFcn', @(btn,event) saveDataCallback());
end

function saveDataCallback()
    global isRunning

    % プログラムの終了フラグを更新してGUIを閉じる
    isRunning = false;
    close all;
end