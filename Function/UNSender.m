% UDP通信を用いて数値を送る関数
function UNSender(data)
    % UDPオブジェクトの作成
    u = udp('127.0.0.1', 'RemotePort', 12345);
    fopen(u);

    % 整数をバイト配列に変換
    bytes = typecast(int32(data), 'uint8');

    % バイト配列を送信
    fwrite(u, bytes, 'uint8');

    % 通信の終了
    fclose(u);
    delete(u);
    clear u;
end

%データの送り方　例）UNSender([50, 50, 50, 50]);