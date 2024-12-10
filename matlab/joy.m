devicePath = '/dev/input/js0';
fid = fopen(devicePath, 'rb');
if fid == -1
    error('Failed to open joystick device. Make sure permissions are correct.');
end
disp('Reading joystick data. Press Ctrl+C to stop.');
safety_is_pressed = false;
previous_angular_velocity = 0.0;
previous_linear_veclocity = 0.0;
try
    while true
        raw_data = fread(fid, 8, 'uint8');

        timestamp = typecast(uint8(raw_data(1:4)), 'uint32'); % Timestamp
        raw_value = typecast(uint8(raw_data(5:6)), 'int16');      % Value
        event_type = raw_data(7);                              % Event type
        number = raw_data(8);                               % Axis or button number

        linear_velocity = 0.0;
        angular_velocity = 0.0;
        if event_type == 1 && number == 2
            safety_is_pressed = (raw_value == 1);

        elseif safety_is_pressed && event_type == 2 && number == 4
            % fprintf('Timestamp: %d, Axis %d: %.6f\n', timestamp, number, norm_value);

            linear_velocity = -1 * double(raw_value) / 32767;
            angular_velocity = previous_angular_velocity;
            previous_linear_veclocity = linear_velocity;

        elseif safety_is_pressed && event_type == 2 && number == 3 
            % fprintf('Timestamp: %d, Axis %d: %.6f\n', timestamp, number, norm_value);

            angular_velocity = double(raw_value) / 32767;
            linear_velocity = previous_linear_veclocity;
            previous_angular_velocity = angular_velocity;

        end

        if linear_velocity < 0.0
            linear_velocity = 0.0;
        end

        fprintf('Linear: %.6f,Angular: %.6f\n', linear_velocity, angular_velocity);
    end
catch error
end
fclose(fid);
disp('Joystick device closed.');
