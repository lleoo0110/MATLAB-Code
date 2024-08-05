% UDP受信テスト

global isRunning udpSocket;

isRunning = true;
portNumber = 12354; % UDPポート番号
% UDPソケットを作成
udpSocket = udp('127.0.0.1', 'LocalPort', portNumber);
fopen(udpSocket); % UDP通信の開始
createSaveDataGUI();

while isRunning
    if udpSocket.BytesAvailable > 0
        % データを受信
        receivedData = fread(udpSocket, udpSocket.BytesAvailable, 'uint8');
        % 受信データを文字列に変換
        str = char(receivedData');
        disp(str);
    end

    % 待機時間
    pause(0.1);
end

%% ボタン構成
function createSaveDataGUI()
    % GUIの作成
    fig = uifigure('Name', '脳波データ保存', 'Position', [100 100 300 150]);
    % 保存ボタンの作成
    btnSave = uibutton(fig, 'push', 'Text', '終了', ...
                       'Position', [75, 55, 150, 40], ...
                       'ButtonPushedFcn', @(btn,event) finCallback(fig));
end

function finCallback(fig)
    global isRunning udpSocket;

    % プログラムの終了フラグを更新してGUIを閉じる
    isRunning = false;
    fclose(udpSocket);
    delete(udpSocket);
    close(fig);
    close all;
end