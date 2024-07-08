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


% データ受信と処理
disp('Now receiving data...');
global Fs  numFilter isRunning portNumber
minf = 1;
maxf = 30;
filtOrder = getOptimalFilterOrder(Fs, minf, maxf);
portNumber = 12354; % UDPポート番号

% EPOC X
Fs = 256;
Ch = {'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'}; % チャンネル
selectedChannels = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]; % 'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'
numFilter =7;

% MN8
% Fs = 128;
% Ch = {'T7','T8'};
% selectedChannels = [4, 5]; % T7, T8のデータを選択

windowSize = 20; % ウィンドウサイズ（秒）
stepSize = 1; % ステップサイズ（秒）
samplesPerWindow = windowSize * Fs; % ウィンドウ内のサンプル数
stepSamples = stepSize * Fs; % ステップサイズに相当するサンプル数

isRunning = true;
dataBuffer = []; % データバッファの初期化

% GUIの作成と表示
createSaveDataGUI();

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
        preprocessedData = preprocessData(dataBuffer(:, 1:samplesPerWindow), Fs, sfiltOrder, minf, maxf); % データの前処理
        analysisData = preprocessedData(:, end-Fs*2+1:end);
        
        % 特徴量抽出
        features12 = extractCSPFeatures(analysisData, cspFilters12);
        features12 = features12';
        features23 = extractCSPFeatures(analysisData, cspFilters23);
        features23 = features23';
        features13 = extractCSPFeatures(analysisData, cspFilters13);
        features13 = features13';
        
        % SVMモデルから予想を出力
        svm_output12 = predict(svmMdl12, features12);
        svm_output23 = predict(svmMdl23, features23);
        svm_output13 = predict(svmMdl13, features13);
        
        % 出力
        if svm_output23 == 2
            if svm_output12 == 1
                predictedClass = 1;
            else
                predictedClass = 2; % 2または3のクラス
            end
        end
        
        if svm_output23 == 3
            if svm_output13 == 1
                predictedClass = 1;
            else
                predictedClass = 3; % 2または3のクラス
            end
        end
        
        % Unityへのデータ通信
        disp(predictedClass);
        udpNumSender(predictedClass);
         
        % データバッファの更新
        dataBuffer = dataBuffer(:, (stepSamples+1):end); % オーバーラップを保持
    end
    
    pause(0.0001);  % 応答性を保つための短い休止
end




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
