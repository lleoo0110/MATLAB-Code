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
dataBuffer = [];

resultHistory = zeros(1, 20);
currentIndex = 1;
while isRunning
    [vec, ts] = inlet.pull_sample(); 
    vec = vec(:); 
 
    if isempty(dataBuffer)
        dataBuffer = vec; 
    else
        dataBuffer = [dataBuffer vec]; 
    end
      
    if size(dataBuffer, 2) >= samplesPerWindow  
        preprocessedData = preprocessData(dataBuffer(params.epocx.selectedChannels, 1:samplesPerWindow), params.eeg.Fs, params.eeg.filtOrder, params.eeg.minf, params.eeg.maxf);
        analysisData = preprocessedData(:, end-params.eeg.Fs*2+1:end);
                
        % 特徴量抽出
        features = extractIntegratedCSPFeatures(analysisData, cspFilters);
        
        [preLabel, preScore] = predict(svmMdl, features);
        
        svmOutput = preLabel;
        
        % svmOutputのログ出力
        fprintf('現在の出力: %d\n', svmOutput);
        
        % 結果履歴の更新
        resultHistory = circshift(resultHistory, [0 1]);
        resultHistory(1) = svmOutput;
        
        % 直前20回の分類結果の割合を計算
        [counts, ~] = histcounts(resultHistory, 'BinMethod', 'integers', 'BinLimits', [1, 4]);
        percentages = counts / 20 * 100;
        
        % percentagesのログ出力
        fprintf('Class Percentages:\n');
        for i = 1:4
            fprintf('  Class %d: %.2f%%\n', i, percentages(i));
        end
        fprintf('\n');  % 見やすさのための空行
        
        % 割合に基づいてUNSenderを呼び出す
        UNSender(percentages);
        
        % 最頻値を計算
%         if ~isempty(resultHistory)
%             mostFrequent = mode(resultHistory);
% 
%             % 感情推定結果送信（最頻値に基づく）
%             if mostFrequent == 1
%                 UNSender([100, 0, 0, 0]);
%             elseif mostFrequent == 2
%                 UNSender([0, 0, 0, 100]);
%             elseif mostFrequent == 3
%                 UNSender([0, 100, 0, 0]);
%             elseif mostFrequent == 4
%                 UNSender([0, 0, 100, 0]);
%             else
%                 UNSender([50, 50, 50, 50]);
%             end
%         end
         
        dataBuffer = dataBuffer(:, (stepSamples+1):end); 
    end
 
    pause(0.0001);  
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
