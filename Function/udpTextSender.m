function udpTextSender(message)
    % UDPソケットの作成
    udpSocket = udp('localhost', 12345);
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