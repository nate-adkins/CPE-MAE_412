%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This is the main code for runing the SMART Robot                  %
% Author: Yu Gu                                                     %
% This is the version with Hukuyo lidar interface                   %
% The Kinect interface is removed                                   % 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all
close all


PGAIN_DIST = 1;
IGAIN_DIST = 0;
DGAIN_DIST = 0;

PGAIN_HEAD = 1;
IGAIN_HEAD = 0;
DGAIN_HEAD = 0;

HEADING_THRESHOLD_DEGREES = 5;
DISTANCE_THRESHOLD_METERS = 1;
REACHED_HEADING = false;

heading_error_integral = 0.0;
distance_error_integral = 0.0;

prev_heading_error = 0.0;
prev_distance_error = 0.0;

% Definitions
Ts_Desired=0.1;           % Desired sampling time
Ts=0.1;                   % sampling time is 0.1 second. It can be reduced 
                          % slightly to offset other overhead in the loop
Tend= 30;                  % Was 60 seconds;
Total_Steps=Tend/Ts_Desired;    % The total number of time steps;
Create_Full_Speed=0.5;      % The highest speed the robot can travel. (Max is 0.5m/s)

% Initialize LIDAR using ROS
rosshutdown % shutdown any previous node
rosinit % initialize a ros node

lidar = rossubscriber('/scan');

% Magnetometer Calibration Data
Mag_A=[  2.3750     0.2485      -0.2296
         0          2.6714      -0.1862
         0          0           2.5061];        % estimated shape of the soft iron effect
Mag_c=[ 0.0067;     0.2667;     0.0473];        % estimated center of the hard iron effect

% Rate Gyro Biases
P_Bias=0;
Q_Bias=0;
R_Bias=0;
% P_Bias=-0.0019;
% Q_Bias= 0.0053;
% R_Bias=-0.0149;

% Define the main Data Structure
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
   
% Initialize the Serial Port for the Data Logger
S_Logger=Init_Logger('0');  % May be different on different computer
% Initialize the Serial Port for iRobot Create
S_Create=RoombaInit('1');    
% Initialize the Serial Port for LightWare Laser Rangefinder
%_LightWare=Init_LightWare('3');     

% Initialize the Serial Port for Hukuyo Lidar
% S_Hokuyo=Init_Hokuyo(7);    % initalize the Lidar
% pause(0.1);
% fscanf(S_Hokuyo)
% rangescan=zeros(1, 682);  

% for i=1:Total_Steps
%     SD.Lidar_Angle(:,i)=(-120:240/682:120-240/682)*pi/180;   % an Array of all the scan angles
% end
% fprintf(S_Hokuyo,'GD0044072500');           % request a scan

flushinput(S_Logger);       % Flush the data logger serial port
flushinput(S_Create);       % Flush the iRobot Create serial port
fwrite(S_Create, [142 0]);  % Request all sensor data from Create
BeepRoomba(S_Create);       % Make a Beeping Sound
pause(0.1);

Proportional_Gain = 1.0;
   
state_est = [0; 0; 0];
P= eye(3);

Q= diag ([.04,.04,.01]);
R= diag ([.25,.25, .04]);

% Starting the main loop
for i=1:Total_Steps
    tic
    SD.Index(i)=i;
    
    % Acquire data from the sensor interface board
    if i==1
        [SD.Logger_Counter(i), SD.Ax(i), SD.Ay(i), SD.Az(i), Raw_P, Raw_Q, Raw_R, Raw_Mx, Raw_My, Raw_Mz, SD.IMU_T(i), A2D_Ch1, A2D_Ch2, SD.RF_F(i), SD.RF_FL(i), SD.RF_L(i), SD.RF_B(i), SD.RF_R(i), SD.RF_FR(i)] = Read_Logger_2(S_Logger,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0); 
    else
        [SD.Logger_Counter(i), SD.Ax(i), SD.Ay(i), SD.Az(i), Raw_P, Raw_Q, Raw_R, Raw_Mx, Raw_My, Raw_Mz, SD.IMU_T(i), A2D_Ch1, A2D_Ch2, SD.RF_F(i), SD.RF_FL(i), SD.RF_L(i), SD.RF_B(i), SD.RF_R(i), SD.RF_FR(i)] = Read_Logger_2(S_Logger,SD.Logger_Counter(i-1),SD.Ax(i-1),SD.Ay(i-1),SD.Az(i-1),Raw_P, Raw_Q, Raw_R, Raw_Mx, Raw_My, Raw_Mz, SD.IMU_T(i-1), A2D_Ch1, A2D_Ch2, SD.RF_F(i-1), SD.RF_FL(i-1), SD.RF_L(i-1), SD.RF_B(i-1), SD.RF_R(i-1), SD.RF_FR(i-1)); 
    end
    SD.P(i)=Raw_P-P_Bias;    SD.Q(i)=Raw_Q-Q_Bias;    SD.R(i)=Raw_R-R_Bias;   % Calibrate the gyro data
    temp=Mag_A*[Raw_Mx-Mag_c(1); Raw_My-Mag_c(2); Raw_Mz-Mag_c(3)];           % Magnetometer Raw Data Correction
    SD.Mx(i)=temp(1); SD.My(i)=temp(2); SD.Mz(i)=temp(3);
    
    flushinput(S_Logger);       % Flush the data logger serial port

 %FLIP THE SMART_BOARD For the New Robot

    SD.Ax(i)=SD.Ax(i)
    SD.Ay(i)=-SD.Ay(i)
    SD.Az(i)=-SD.Az(i)
    SD.P(i)=SD.P(i)
    SD.Q(i)=-SD.Q(i)
    SD.R(i)=-SD.R(i)
    SD.Mx(i)=SD.Mx(i)
    SD.My(i)=-SD.My(i)
    SD.Mz(i)=-SD.Mz(i)
    
%     % Acquire data from the LightWare Laser Rangefinder
%     if i==1
%         SD.Laser_RF(i) = Read_LightWare(S_LightWare,0);
%     else
%         SD.Laser_RF(i) = Read_LightWare(S_LightWare,SD.Laser_RF(i-1));
%     end
%     flushinput(S_LightWare);    % Flush the LightWare Laser Rangefinder serial port

    % Acquire the data from the iRobot Create
    [BumpRight,BumpLeft,BumpFront,SD.Wall(i),SD.VirtWall(i),CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,LeftCurrOver,RightCurrOver,DirtL,DirtR,ButtonPlay,ButtonAv,SD.Dist(i),SD.Angle(i),SD.CreateVolts(i),SD.CreateCurrent(i),Temp,Charge,Capacity,pCharge]=Read_Create_2(S_Create);
    flushinput(S_Create);       % Flush the iRobot Create serial port
    fwrite(S_Create, [142 0]);  % Request all sensor data from Create

    % Acquire data from Hukuyo Lidar
%     rangescan = Read_Hokuyo(S_Hokuyo, rangescan);
%     SD.Lidar_Range(:,i)=rangescan;
%     SD.Laser_RF(i) = rangescan(341);    % simulated laser rangefinder using the LIDAR center spot
%     plot(rangescan);
%     drawnow

%     flushinput(S_Hokuyo);       % Flush the Lidar serial port
%     fprintf(S_Hokuyo,'GD0044072500');           % request a new Lidar scan

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
    
    
    if mod(i,2)==0
        lidar_data = receive(lidar,2);
        display(lidar_data.Ranges(1))
    % Comment out the plot functions to have better performance.        
         plot(lidar_data)
         drawnow
    end
    %% Put your custom control functions here
    %----------------------------------------------------------
    % Use the following function for the robot wheel control:
    % SetDriveWheelsSMART(S_Create, rightWheelVel, leftWheelVel, SD.CliffLeft(i),SD.CliffRight(i),SD.CliffFrontLeft(i),SD.CliffFrontRight(i));
%     u = [SD.Dist(i)/Ts;SD.Angle(i)/Ts];
%     dt = Ts;
% 
%     %state predictopm
%     theta = state_est(3);
%     state_pred = state_est+ [
%         u(1) * cos(theta)*dt;
%         u(1)* sin(theta)*dt; 
%         u(2) * dt
%         ];
% 
%     % Jacobian for F
%     F = [
%       1, 0, -u(1) * sin(theta) * dt;
%       0, 1,  u(1) * cos(theta) * dt;
%       0, 0,  1
%     ];
%     
%     %cov_prediction
%     cov_prediction = F * P * F' + Q*dt^2;
% 
%     % Measurement step
%     z = [SD.X(i); SD.Y(i); SD.Yaw(i)];  % Measurements (e.g., dead reckoning, lidar)
%     
%     % Predicted measurement
%     z_pred = state_pred;  % Assuming direct measurements of state variables
%     
%     % Jacobian of h (measurement model)
%     H = eye(3);
%     
%     % Kalman gain
%     K = cov_prediction * H' / (H * cov_prediction * H' + R);
%     
%     % Update state estimate
%     state_est = state_pred + K * (z - z_pred);
%     
%     % Update covariance
%     P = (eye(3) - K * H) * cov_prediction;

    goal_x = 0.5;
    goal_y = 0.5;
    x_error = goal_x - SD.X(i);
    y_error = goal_y - SD.Y(i);

    % Inputs to controllers 
    heading_error = atan2(y_error, x_error) - SD.Yaw(i);
    distance_error = sqrt((x_error^2)+(y_error)^2);

    heading_error_integral = heading_error_integral + heading_error; 
    distance_error_integral = distance_error_integral + distance_error;

    heading_derivative = (prev_heading_error - heading_error)/Ts_Desired;
    distance_derivative = (prev_distance_error - distance_error)/Ts_Desired;

    % PID Controller Output
    heading_control_output = PGAIN_HEAD * heading_error + IGAIN_HEAD * heading_error_integral + DGAIN_HEAD * heading_derivative;
    distance_control_output = PGAIN_DIST * distance_error + IGAIN_DIST * distance_error_integral + DGAIN_DIST * distance_derivative;


    if REACHED_HEADING
        % Drive straight
        if distance_error > DISTANCE_THRESHOLD_METERS
            left_speed = distance_control_output; 
            right_speed = distance_control_output;
        else
            left_speed = 0; 
            right_speed = 0;
        end

    else
        if heading_error > deg2rad(HEADING_THRESHOLD_DEGREES)
            % Turn robot
            left_speed = -1 * heading_control_output * 0.2;
            right_speed = heading_control_output * 0.2;
        else
            REACHED_HEADING = true;
            left_speed = 0;
            right_speed = 0;
        end
    end

    disp(left_speed)
    disp(right_speed)

    SetDriveWheelsSMART(S_Create, left_speed, right_speed, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);


    prev_heading_error = heading_error;
    prev_distance_error = distance_error;

    % SetDriveWheelsSMART(S_Create, Create_Full_Speed-P_cont, Create_Full_Speed+P_cont, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);

    % x= -0.5;
    % y= -0.5;
    % X_E = x - SD.X(i);
    % y_E = y - SD.Y(i);

    % theta_goal = atan2(y_E,X_E);
    % disp(theta_goal)
    % theta_error = theta_goal - SD.Yaw(i);
    % disp(theta_error)
    % P_cont = Proportional_Gain *.2 * theta_error;

    % SetDriveWheelsSMART(S_Create, Create_Full_Speed-P_cont, Create_Full_Speed+P_cont, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);

    
    % Collision Avoidance Example(Set Tend=60s)
%     if SD.RF_F(i)<500
%         SetDriveWheelsSMART(S_Create, -Create_Full_Speed*.4, -Create_Full_Speed*.6, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);
%     elseif SD.RF_B(i)<300
%         SetDriveWheelsSMART(S_Create, Create_Full_Speed*.6, Create_Full_Speed*.4, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);
%     elseif SD.RF_L(i)<500
%         SetDriveWheelsSMART(S_Create, -Create_Full_Speed*.5, Create_Full_Speed*0.5, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);
%     elseif SD.RF_R(i)<500
%         SetDriveWheelsSMART(S_Create, Create_Full_Speed*0.5, -Create_Full_Speed*.5, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);
%     else
%         SetDriveWheelsSMART(S_Create, Create_Full_Speed, Create_Full_Speed, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);
%     end

    %----------------------------------------------------------
    %% End of the Custom Control Code

    % Calculate the tinputime left in the constant interval
    SD.Delay(i)=Ts-toc;         
    if SD.Delay(i)>0
        pause(SD.Delay(i));     % Kill the remaining time
    end
end
Total_Elapse_Time=SD.Time(Total_Steps)-SD.Time(1)  % Calcualte the total elapse time, not counting the minutes
SetDriveWheelsSMART(S_Create, 0, 0, CliffLeft,CliffRight,CliffFrontLeft,CliffFrontRight,BumpRight,BumpLeft,BumpFront);       % Stop the wheels
BeepRoomba(S_Create);       % Make a Beeping Sound

% Properly close the serial ports
delete(S_Logger)
clear S_Logger  
delete(S_Create)
clear S_Create  
%delete(S_LightWare)
%clear S_LightWare  
% fprintf(S_Hokuyo,'QT');
% fclose(S_Hokuyo);

save('SMART_DATA.mat', 'SD');       % Save all the collected data to a .mat file
% SMART_PLOT;                         % Plot all the robot data
