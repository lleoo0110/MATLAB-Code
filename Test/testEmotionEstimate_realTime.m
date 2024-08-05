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

% EEGデータ収集
saveInterval = 60; % 保存間隔（秒）
fileIndex = 1;
lastSaveTime = tic;
lastSampleTime = tic;
sampleCounter = 0;
while isRunning
    currentTime = toc(lastSampleTime);
    samplesNeeded = floor(currentTime * params.eeg.Fs) - sampleCounter;
    
    if samplesNeeded > 0
        for i = 1:samplesNeeded
            % 擬似EEGサンプルを生成
            eegSample = generateFakeEEGSample(19, params.simulation.amplitude, params.simulation.noise_level);
            sampleCounter = sampleCounter + 1;
            
            % データバッファの更新（チャンネルごとにデータを追加）
            if isempty(dataBuffer)
                dataBuffer = eegSample'; % 最初のデータセットの場合
            else
                dataBuffer = [dataBuffer eegSample']; % データを追加
            end
        end
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
        udpNumSender(svmOutput);
         
        % データバッファの更新
        dataBuffer = dataBuffer(:, (stepSamples+1):end); % オーバーラップを保持
    end

    pause(0.0001);  % 応答性を保つための短い休止
    
    % 1秒ごとにカウンターをリセット
    if currentTime >= 1
        lastSampleTime = tic;
        sampleCounter = 0;
    end
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
