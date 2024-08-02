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
    'portNumber', 12354, ...
    'threshold', 0.5, ...
    'windowSize', 15, ...
    'stepSize', 1 ...
);

% 擬似脳波データ生成のためのパラメータを追加
params.simulation = struct(...
    'amplitude', 50, ... % マイクロボルト単位の振幅
    'noise_level', 5 ... % ノイズレベル
);

% EPOCX設定（14Ch）
params.epocx = struct(...
    'channels', {{'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'}}, ... % チャンネル
    'selectedChannels', [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17] ... % 'AF3','F7','F3','FC5','T7','P7','O1','O2','P8','T8','FC6','F4','F8','AF4'
);

% 変数
isRunning = true;
numFilter = params.eeg.numFilter;
portNumber = params.experiment.portNumber;
Ch = params.epocx.channels;
samplesPerWindow = params.experiment.windowSize * params.eeg.Fs; % ウィンドウ内のサンプル数
stepSamples = params.experiment.stepSize * params.eeg.Fs; % ステップサイズに相当するサンプル数


%% 脳波データ計測
% GUIの作成と表示
createSaveDataGUI();
dataBuffer = []; % データバッファの初期化
% 結果とタイムスタンプを保存するための配列を初期化
resultHistory = zeros(1, 15);
timeHistory = zeros(1, 15);
currentIndex = 1;
while isRunning
    % 現在の時刻を取得
    currentTime = now;
    [vec, ts] = inlet.pull_sample(); % データの受信
    vec = vec(:); % 1x19の行ベクトルを19x1の列ベクトルに変換

    % データバッファの更新（チャンネルごとにデータを追加）
    if isempty(dataBuffer)
        dataBuffer = vec; % 最初のデータセットの場合
    else
        dataBuffer = [dataBuffer vec]; % データを追加
    end
      
    if size(dataBuffer, 2) >= samplesPerWindow  
        preprocessedData = preprocessData(dataBuffer(params.epocx.selectedChannels, 1:samplesPerWindow), params.eeg.Fs, params.eeg.filtOrder, params.eeg.minf, params.eeg.maxf);
        analysisData = preprocessedData(:, end-params.eeg.Fs*2+1:end);
                
        % 特徴量抽出
        features = extractIntegratedCSPFeatures(analysisData, cspFilters);
        
        % SVMモデルから予想を出力
        [preLabel, preScore] = predict(svmMdl, features);
        
        svmOutput= preLabel;
        
        % Unityへのデータ通信
        disp(svmOutput);
        
        % 結果とタイムスタンプを履歴に追加
        resultHistory(currentIndex) = svmOutput;
        timeHistory(currentIndex) = currentTime;
        currentIndex = mod(currentIndex + 1, 15);
        if currentIndex == 0
            currentIndex = 15;
        end

        % Unityへのデータ通信
        disp(svmOutput);

        % 直近15秒のデータのみを使用
        recentIndices = find(currentTime - timeHistory <= 15/86400); % 15秒をMATLABの日付形式に変換
        recentResults = resultHistory(recentIndices);

        % 最頻値を計算（直近15秒のデータのみ使用）
        if ~isempty(recentResults)
            mostFrequent = mode(recentResults);

            % 感情推定結果送信（最頻値に基づく）
            if mostFrequent == 1
                UNSender([100, 0, 0, 0]);
            elseif mostFrequent == 2
                UNSender([0, 0, 0, 100]);
            elseif mostFrequent == 3
                UNSender([0, 100, 0, 0]);
            elseif mostFrequent == 4
                UNSender([0, 0, 100, 0]);
            end
        end
         
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
