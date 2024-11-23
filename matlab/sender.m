ip_address = '127.0.0.1';  
port = 12346;              
tcp_sender = tcpclient(ip_address, port);
num_messages = 100;

try
    for i = 1:num_messages
        message = [int32(i)];
        write(tcp_sender, message);
    end
catch ME
    disp(['Error occurred: ', ME.message]);
end
clear tcp_sender;
