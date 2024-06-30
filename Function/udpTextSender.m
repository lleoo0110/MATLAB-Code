function udpTextSender(message)
    global portNumber
    % UDPソケットの作成
    udpSocket = udp('localhost', portNumber);
    udpSocket.OutputBufferSize = 1024;
    
    % UDPソケットを開く
    fopen(udpSocket);
    fprintf(udpSocket, message);
    disp('Message sent.');
    
    % UDPソケットを閉じる
    fclose(udpSocket);
    
    % UDPソケットを削除
    delete(udpSocket);
    clear udpSocket;
end