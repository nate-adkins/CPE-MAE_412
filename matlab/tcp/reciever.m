ip_address = '127.0.0.1';  
port = 12346;       
tcp_receiver = tcpserver(ip_address, port);

disp('Waiting for data...');
while true
    if tcp_receiver.NumBytesAvailable > 0
        received_data = read(tcp_receiver, 1, "int32");
        received_int = received_data(1);
        disp(['Received int: ', num2str(received_int)]);
    end
end
