%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This is the main code for runing the SMART Robot                  %
% Author: Yu Gu                                                     %
% This is the version with Hukuyo lidar interface                   %
% The Kinect interface is removed                                   % 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all
close all

diary(['logs/output_log_' datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS') '.txt']);

SCALING_FACTOR = 500;
REACHED_HEADING = false;
REACHED_DISTANCE = false;
goal_index = 1;

heading_error_integral = 0.0;
distance_error_integral = 0.0;

prev_heading_error = 1000;
prev_distance_error = 1000;

%Letter Input function
Word_matrix = Input_to_Letter();

% Definitions
Ts_Desired=0.1;           % Desired sampling time
Ts=0.1;                   % sampling time is 0.1 second. It can be reduced 
                          % slightly to offset other overhead in the loop
Tend= 300;                  % Was 60 seconds;
Total_Steps=Tend/Ts_Desired;    % The total number of time steps;
Create_Full_Speed=0.5;      % The highest speed the robot can travel. (Max is 0.5m/s)

% Initialize LIDAR using ROS
% rosshutdown % shutdown any previous node
% rosinit % initialize a ros node


% lidar = rossubscriber('/scan');

% Magnetometer Calibration Data
Mag_A=[  2.3750     0.2485      -0.2296
         0          2.6714      -0.1862
         0          0           2.5061];        % estimated shape of the soft iron effect
Mag_c=[ 0.0067;     0.2667;     0.0473];        % estimated center of the hard iron effect

% Rate Gyro Biases
P_Bias=0;
Q_Bias=0;
R_Bias=0;

SD= struct( 'Index',zeros(1,Total_Steps),...            % SD stands for SMART Data, which stores all the robot data
            'Time', zeros(1,Total_Steps),...            % The actual time at each time step (s) 
            'Time_Diff', zeros(1,Total_Steps),...       % The time difference between two step (s) 
            'Delay',zeros(1,Total_Steps),...            % Delay needed between each time step. It indicate how much time avaliable for other compuations. 
            'Lidar_Angle', zeros(682,Total_Steps),...   % Hukuyo Lidar Scan Angles             
            'Lidar_Range', zeros(682,Total_Steps),...   % Hukuyo Lidar Scan Range             
            'Logger_Counter', zeros(1,Total_Steps),...  % The Counter number for the SMART data logger 
            'Ax',zeros(1,Total_Steps),...               % Acceleration along the x-Axis (g)
            'Ay',zeros(1,Total_Steps),...               % Acceleration along the y-Axis (g)
            'Az',zeros(1,Total_Steps),...               % Acceleration along the z-Axis (g)
            'P',zeros(1,Total_Steps),...                % Roll Rate (deg/s)
            'Q',zeros(1,Total_Steps),...                % Pitch Rate (deg/s)
            'R',zeros(1,Total_Steps),...                % Yaw Rate (deg/s)
            'Mx',zeros(1,Total_Steps),...               % Magnetic strength along the x-axis (G)
            'My',zeros(1,Total_Steps),...               % Magnetic strength along the y-axis (G)
            'Mz',zeros(1,Total_Steps),...               % Magnetic strength along the z-axis (G)
            'IMU_T',zeros(1,Total_Steps),...            % IMU internal temperacture (C)
            'Roll',zeros(1,Total_Steps),...             % Roll Angle (rad)
            'Pitch',zeros(1,Total_Steps),...            % Pitch Angle (rad)
            'Yaw',zeros(1,Total_Steps),...              % Yaw Angle (rad) 
            'Mag_Heading',zeros(1,Total_Steps),...      % Magnetic Heading (rad) 
            'X',zeros(1,Total_Steps),...                % Robot X Position (m) 
            'Y',zeros(1,Total_Steps),...                % Robot Y Position (m) 
            'RF_F',zeros(1,Total_Steps),...             % Front Range Finder (mm)
            'RF_FL',zeros(1,Total_Steps),...            % Front-Left Range Finder (mm)
            'RF_L',zeros(1,Total_Steps),...             % Left Range Finder (mm)
            'RF_B',zeros(1,Total_Steps),...             % Back Range Finder (mm)
            'RF_R',zeros(1,Total_Steps),...             % Right Range Finder (mm)
            'RF_FR',zeros(1,Total_Steps),...            % Front Right Range Finder (mm)
            'Laser_RF', zeros(1,Total_Steps),...        % Laser Range Finder (mm)
            'Wall', zeros(1,Total_Steps),...            % Wall sensor of Create (0/1)
            'VirtWall', zeros(1,Total_Steps),...        % Detect the Virtual Wall (0/1)
            'Dist', zeros(1,Total_Steps),...            % Distance Traveled Since Last Call (m)
            'TotalDist', zeros(1,Total_Steps),...       % Total Distance Traveled(m)
            'Angle', zeros(1,Total_Steps),...           % Angle Traveled Since Last Call (rad)
            'TotalAngle', zeros(1,Total_Steps),...      % Total Angle Traveled (rad)
            'CreateVolts', zeros(1,Total_Steps),...     % Voltage of the Create Robot (rad)
            'CreateCurrent', zeros(1,Total_Steps));     % Current of the Create Robot (rad)
   
S_Logger=Init_Logger('1');
S_Create=RoombaInit('2');    

flushinput(S_Logger);       % Flush the data logger serial port
flushinput(S_Create);       % Flush the iRobot Create serial port
fwrite(S_Create, [142 0]);  % Request all sensor data from Create
BeepRoomba(S_Create);       % Make a Beeping Sound
pause(0.1);

   
state_est = [0; 0; 0];
P= eye(3);

Q= diag ([.04,.04,.01]);
R= diag ([.25,.25, .04]);

for i=1:Total_Steps
    tic
    SD.Index(i)=i;
    
    if i==1
        [SD.Logger_Counter(i), SD.Ax(i), SD.Ay(i), SD.Az(i), Raw_P, Raw_Q, Raw_R, Raw_Mx, Raw_My, Raw_Mz, SD.IMU_T(i), A2D_Ch1, A2D_Ch2, SD.RF_F(i), SD.RF_FL(i), SD.RF_L(i), SD.RF_B(i), SD.RF_R(i), SD.RF_FR(i)] = Read_Logger_2(S_Logger,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0); 
    else
        [SD.Logger_Counter(i), SD.Ax(i), SD.Ay(i), SD.Az(i), Raw_P, Raw_Q, Raw_R, Raw_Mx, Raw_My, Raw_Mz, SD.IMU_T(i), A2D_Ch1, A2D_Ch2, SD.RF_F(i), SD.RF_FL(i), SD.RF_L(i), SD.RF_B(i), SD.RF_R(i), SD.RF_FR(i)] = Read_Logger_2(S_Logger,SD.Logger_Counter(i-1),SD.Ax(i-1),SD.Ay(i-1),SD.Az(i-1),Raw_P, Raw_Q, Raw_R, Raw_Mx, Raw_My, Raw_Mz, SD.IMU_T(i-1), A2D_Ch1, A2D_Ch2, SD.RF_F(i-1), SD.RF_FL(i-1), SD.RF_L(i-1), SD.RF_B(i-1), SD.RF_R(i-1), SD.RF_FR(i-1)); 
    end
    SD.P(i)=Raw_P-P_Bias;    SD.Q(i)=Raw_Q-Q_Bias;    SD.R(i)=Raw_R-R_Bias;   % Calibrate the gyro data
    temp=Mag_A*[Raw_Mx-Mag_c(1); Raw_My-Mag_c(2); Raw_Mz-Mag_c(3)];           % Magnetometer Raw Data Correction
    SD.Mx(i)=temp(1); SD.My(i)=temp(2); SD.Mz(i)=temp(3);
    
    flushinput(S_Logger);       % Flush the data logger serial port

    SD.Ax(i)=SD.Ax(i);
    SD.Ay(i)=-SD.Ay(i);
    SD.Az(i)=-SD.Az(i);
    SD.P(i)=SD.P(i);
    SD.Q(i)=-SD.Q(i);
    SD.R(i)=-SD.R(i);
    SD.Mx(i)=SD.Mx(i);
    SD.My(i)=-SD.My(i);
    SD.Mz(i)=-SD.Mz(i);

    [BumpRight,BumpLeft,BumpFront,SD.Wall(i),SD.VirtWall(i),CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,LeftCurrOver,RightCurrOver,DirtL,DirtR,ButtonPlay,ButtonAv,SD.Dist(i),SD.Angle(i),SD.CreateVolts(i),SD.CreateCurrent(i),Temp,Charge,Capacity,pCharge]=Read_Create_2(S_Create);
    flushinput(S_Create);       % Flush the iRobot Create serial port
    fwrite(S_Create, [142 0]);  % Request all sensor data from Create

    Time=clock;                     % Mark the current time;
    SD.Time(i)=Time(6);             % Store the seconds;
    if i==1
        SD.Roll(i)=0; %atan2(SD.Ay(i), SD.Az(i));                                 % Calculate the Roll angle based on the gravity vector
        SD.Pitch(i)=0; %atan(-SD.Ax(i)/(SD.Ay(i)*sin(SD.Roll(i))+SD.Az(i)*cos(SD.Roll(i))));    % Calculate the Roll angle based on the pitch vector
        SD.Mag_Heading(i)=atan2(-SD.My(i), SD.Mx(i));                         % The initial 2D magnetic heading of the robot
        SD.Yaw(i)=0;                                                          % Set the current yaw angle as zero
        Attitude_P=zeros(3,3);                                                % Initialization the error covariance matrix for attitude estimation 
        SD.X(i)=0;                                                            % Initial Robot X Position
        SD.Y(i)=0;                                                            % Inital Robot Y Position
    else                                                                      % If i>1
        SD.Time_Diff(i)=SD.Time(i)-SD.Time(i-1);                              % Calculate the time difference between steps
        if SD.Time_Diff(i)<0
            SD.Time_Diff(i)=SD.Time_Diff(i)+60;                               % Compensate for the minute change
        end
        SD.TotalDist(i)=SD.TotalDist(i-1)+SD.Dist(i);                         % Calculate the total traveled distance based on the encoder reading
        SD.TotalAngle(i)=SD.TotalAngle(i-1)+SD.Angle(i);                      % Calculate the total traveled angle based on the encoder reading
        
        SD.Mag_Heading(i)=atan2(-SD.My(i), SD.Mx(i));                         % The 2D magnetic heading of the robot

        [SD.Roll(i), SD.Pitch(i), SD.Yaw(i), Attitude_P] = Attitude_Estimation(SD.Mag_Heading(1), SD.Roll(i-1), SD.Pitch(i-1), SD.Yaw(i-1), SD.Time_Diff(i), Attitude_P, SD.Ax(i), SD.Ay(i), SD.Az(i), SD.P(i), SD.Q(i), SD.R(i), SD.Mx(i), SD.My(i), SD.Mz(i));     % Perform the attitude estimation 
        SD.X(i)=SD.X(i-1)+SD.Dist(i)*cos(SD.Yaw(i));                          % Dead Reckoning for X position
        SD.Y(i)=SD.Y(i-1)+SD.Dist(i)*sin(SD.Yaw(i));                          % Dead Reckoning for Y position
    end

    u = [SD.Dist(i)/Ts;SD.Angle(i)/Ts];
    dt = Ts;

    %state predicton
    theta = state_est(3);
    state_pred = state_est+ [
        u(1) * cos(theta)*dt;
        u(1)* sin(theta)*dt; 
        u(2) * dt
        ];

    % Jacobian for F
    F = [
      1, 0, -u(1) * sin(theta) * dt;
      0, 1,  u(1) * cos(theta) * dt;
      0, 0,  1
    ];
    
    %cov_prediction
    cov_prediction = F * P * F' + Q;

    % Measurement step
    z = [SD.X(i); SD.Y(i); SD.Yaw(i)];  % Measurements (e.g., dead reckoning, lidar)
    
    % Predicted measurement
    z_pred = state_pred;  % Assuming direct measurements of state variables
    
    % Jacobian of h (measurement model)
    H = eye(3);
    
    % Kalman gain
    K = cov_prediction * H' / (H * cov_prediction * H' + R);
    
    % Update state estimate
    state_est = state_pred + K * (z - z_pred);
    
    % Update covariance
    P = (eye(3) - K * H) * cov_prediction;

    goal_points = Word_matrix;

    % goal_points = [ 0.25, 0.2;
    %                 0.0, 0.0;
    %             ] * SCALING_FACTOR;

    goal_x = goal_points(goal_index,2)/SCALING_FACTOR;
    goal_y = goal_points(goal_index,1)/SCALING_FACTOR;

    % x_error = goal_x - SD.X(i);
    % y_error = goal_y - SD.Y(i);
    x_error = goal_x - state_est(1);
    y_error = goal_y - state_est(2);

    % if  i < 10 && i > 5 && SD.Yaw(i) == 0.0
    %     disp("Did not recieve yaw data")
    %     SetDriveWheelsSMART(S_Create, 0.0, 0.0, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);
    %     pause(3)
    %     exit;
    % end

    TURNING_LEFT = false;
    HEADING_THRESHOLD_DEGREES = 3;
    DISTANCE_THRESHOLD_METERS = 0.07;

    PGAIN_DIST = 3;
    IGAIN_DIST = 0.15;
    DGAIN_DIST = 0;

    PGAIN_HEAD = 2.0;
    IGAIN_HEAD = 0.01;
    DGAIN_HEAD = 0.0;

    % heading_error = atan2(y_error, x_error) - SD.Yaw(i);
    heading_error = atan2(y_error, x_error) - state_est(3);
    heading_error = mod(heading_error,2*pi);

    if heading_error > deg2rad(180)
        heading_error = (2*pi) - heading_error;
        TURNING_LEFT = true;
    end

    distance_error = sqrt((x_error^2)+(y_error)^2);
    
    heading_error_integral = heading_error_integral + heading_error;

    if REACHED_HEADING
        distance_error_integral = distance_error_integral + distance_error;
    end

    heading_derivative = (prev_heading_error - heading_error)/Ts_Desired;
    distance_derivative = (prev_distance_error - distance_error)/Ts_Desired;

    % PID Controller Output
    heading_control_output = PGAIN_HEAD * heading_error + IGAIN_HEAD * heading_error_integral - DGAIN_HEAD * heading_derivative;
    distance_control_output = PGAIN_DIST * distance_error + IGAIN_DIST * distance_error_integral - DGAIN_DIST * distance_derivative;

    fprintf("\nGoal index %1.0f\n",goal_index)
    fprintf("Heading error %1.4f\n",rad2deg(heading_error))
    fprintf("Distance error %1.4f\n",distance_error)
    fprintf("Current goal point x:%1.4f y:%1.4f\n",goal_x, goal_y)
    fprintf("Current sums: head:%1.4f dist:%1.4f\n",heading_error_integral, distance_error_integral)

    if REACHED_HEADING && REACHED_DISTANCE
        disp("    New goal")
        REACHED_HEADING = false;
        REACHED_DISTANCE = false;
        goal_index = goal_index + 1;
        left_speed = 0.0;
        right_speed = 0.0;
        heading_error_integral = 0.0;
        distance_error_integral = 0.0;

        if goal_index > length(goal_points)
            disp("End of goal points")
            pause(5)
            diary off;
            return
        end

    elseif REACHED_HEADING
        if (distance_error > prev_distance_error + (DISTANCE_THRESHOLD_METERS/2)) 
            disp("    Driving - Stop due to overshoot")
            REACHED_DISTANCE = true;
            left_speed = 0; 
            right_speed = 0;

        elseif (distance_error > DISTANCE_THRESHOLD_METERS)
            disp("    Driving - Moving")
            left_speed = distance_control_output * 0.3; 
            right_speed = distance_control_output * 0.3;

        elseif (distance_error <= DISTANCE_THRESHOLD_METERS)
            disp("    Driving - Stop")
            REACHED_DISTANCE = true;
            left_speed = 0; 
            right_speed = 0;

        end
        prev_distance_error = distance_error;
        disp("Real update to previous distance error")

    else
        if abs(heading_error) > deg2rad(HEADING_THRESHOLD_DEGREES)
            
            % MIN_SPEED = 0.10;

            speed = heading_control_output * 0.05;
            % speed = max(speed,MIN_SPEED)
            
            if TURNING_LEFT
                disp("    Turning - Left")
                left_speed = -1 * speed;
                right_speed = speed;
                TURNING_LEFT = false;
            else
                disp("    Turning - Right")
                left_speed = speed;
                right_speed = -1 * speed;     
            end 

        else
            disp("    Turning - Stop")
            REACHED_HEADING = true;
            left_speed = 0;
            right_speed = 0;
            prev_distance_error = 1000;
            disp("Previous distance error set to 1000")
        end

    end

    fprintf("speeds: left:%1.2fright:%1.2f\n",left_speed,right_speed)


    SetDriveWheelsSMART(S_Create, right_speed, left_speed, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);


    prev_heading_error = heading_error;

    SD.Delay(i)=Ts-toc;         
    if SD.Delay(i)>0
        pause(SD.Delay(i));     % Kill the remaining time
    end
end
Total_Elapse_Time=SD.Time(Total_Steps)-SD.Time(1);  % Calcualte the total elapse time, not counting the minutes
SetDriveWheelsSMART(S_Create, 0, 0, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);       % Stop the wheels
BeepRoomba(S_Create);       % Make a Beeping Sound

% Properly close the serial ports
delete(S_Logger)
clear S_Logger  
delete(S_Create)
clear S_Create  
diary off;
% save('SMART_DATA.mat', 'SD');       % Save all the collected data to a .mat file
% SMART_PLOT;                         % Plot all the robot data