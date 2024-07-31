%% パスの追加
mfilepath=fileparts(which(mfilename));
addpath(fullfile(mfilepath,'./liblsl-Matlab'));
addpath '/Users/lleoo/Documents/MATLAB Repogitory/program/RTBCI'
% addpath '/Users/lleoo/Documents/大学授業/研究/AHs2024/Experiment1/onomatopoeia/labels'

if ismac
    %le Code to run on Mac platform
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


%% パラメータ設定
disp('Now receiving data...');
global numFilter isRunning portNumber
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

% 実験用パラメータ
params.experiment = struct(...
    'portNumber', 12354 ...
);

% EPOCX設定（14Ch）
params.epocx = struct(...
    'channels', {{'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'}}, ... % チャンネル
    'selectedChannels', [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17] ... % 'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'
);

% グローバル変数の設定
isRunning = false;
numFilter = params.eeg.numFilter;
portNumber = params.experiment.portNumber;
Ch = params.epocx.channels;


%% 脳波データ計測
% GUIの作成と表示
createSaveDataGUI();
dataBuffer = []; % データバッファの初期化
while isRunning
    [vec, ts] = inlet.pull_sample(); % データの受信
    vec = vec(:); % 1x19の行ベクトルを19x1の列ベクトルに変換
    eegData = [eegData vec];
    
    % データバッファの更新（チャンネルごとにデータを追加）
    if isempty(dataBuffer)
        dataBuffer = eegData; % 最初のデータセットの場合
    else
        dataBuffer = [dataBuffer eegData]; % データを追加
    end
    
    
    if size(dataBuffer, 2) >= samplesPerWindow  
        preprocessedData = preprocessData(dataBuffer(params.epocx.selectedChannels, 1:samplesPerWindow), params.eeg.Fs, params.eeg.filtOrder, params.eeg.minf, params.eeg.maxf);
        analysisData = preprocessedData(:, end-Fs*2+1:end);
                
        % 特徴量抽出
        features = extractCSPFeatures(analysisData, cspFilters);
        
        % SVMモデルから予想を出力
        [preLabel, preScore] = predict(svmMdl, features);
        
        % 閾値による決定
        if preScore(1,1) >= threshold
            svm_output = 1;  % 正のクラス
        else
            svm_output = 2;  % 負のクラス
        end
        
        % Unityへのデータ通信
        disp(preScore(1,1));
        disp(svm_output);
        udpNumSender(svm_output);
         
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
