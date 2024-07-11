% UDP通信テスト用(一井が勝手に追加)

createSaveDataGUI();
global isRunning num portNumber;
isRunning=true;
num=1;
portNumber = 12354;
delayTime=0.25;

% 開始時間を取得
tic;

while isRunning
    % 現在の時間を取得
    elapsedTime = toc;

    % 経過時間がdelayTime秒以上ならばデータを送信
    if elapsedTime >= delayTime
        udpNumSender(num);
        disp(num);
        % ticを再設定して0.25秒のカウントをリセット
        tic;
    end

    % 過度のCPU使用率を防ぐための小さな休止
    pause(1);
end

function createSaveDataGUI()
    % GUIの作成
    fig = uifigure('Name', 'テストデータ送信', 'Position', [100 100 300 150]);
    
    btn1= uibutton(fig, 'push', 'Text', '1', ...
                       'Position', [75, 80, 40, 40], ...
                       'ButtonPushedFcn', @(btn,event) changeNum(1));

    btn2= uibutton(fig, 'push', 'Text', '2', ...
                       'Position', [130, 80, 40, 40], ...
                       'ButtonPushedFcn', @(btn,event) changeNum(2));

    btn3= uibutton(fig, 'push', 'Text', '3', ...
                       'Position', [185, 80, 40, 40], ...
                       'ButtonPushedFcn', @(btn,event) changeNum(3));

    % 終了ボタンの作成
    btnFin = uibutton(fig, 'push', 'Text', '終了', ...
                       'Position', [75, 30, 150, 40], ...
                       'ButtonPushedFcn', @(btn,event) saveDataCallback(fig));
end

function saveDataCallback(fig)
    global isRunning

    % UDPソケットを閉じる
    clear udpSocket;

    % プログラムの終了フラグを更新してGUIを閉じる
    isRunning = false;
    close(fig);
    close all;
end

function changeNum(n)
    global num;
    num=n;
end