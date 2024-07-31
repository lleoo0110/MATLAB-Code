% UDP Receiverの作成
udpr = dsp.UDPReceiver('LocalIPPort', 8890, 'RemoteIPAddress', '127.0.0.1');

setup(udpr);
disp('MATLABサーバが起動しました。データを待っています...');



while true
    % データの受信
    dataReceived = step(udpr);

    if ~isempty(dataReceived)
        % 受信したデータを文字列に変換
        message = char(dataReceived)';
        disp(['受信したデータ: ', message]);
    end
    pause(0.1); % サーバの負荷を下げるための待機
end
