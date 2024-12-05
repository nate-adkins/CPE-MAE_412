% Initialize ports 
roomba_port = serialport("/dev/ttyUSB0",57600, "Timeout", 1.0);
sensor_port = serialport("/dev/ttyUSB1",115200, "Timeout", 0.1);

send_start_mode(roomba_port)
send_control_mode(roomba_port)
% Initialize ports 

total_distance = 0;
total_angle = 0;
curr_x = 0;
curr_y = 0;
curr_yaw = 0;

try
    while true
        % <iterate through goal points>
            % <update current goal point>

        [distance_delta, angle_delta] = read_data(roomba_port)

        total_distance = total_distance + distance_delta
        total_angle = total_angle + angle_delta

        % read data 
        % get state esitmate 

        % run PID controller for goal point
        % check if reasonably close 


    end 
catch exception
    if strcmp(exception.identifier, 'MATLAB:interrupt')
    disp('Keyboard interrupt detected. Exiting loop, zeroing motors');

end