FORMAT = "unit8";

function send_start_mode(serial_port)
    % Starts the SCI. The Start command must be sent before any other SCI commands
    opcode = 128;
    write(serial_port, opcode, FORMAT);
end

function send_full_mode(serial_port)
    % Enables unrestricted control of Roomba through the serial interfa and turns off the safety features
    opcode = 132;
    write(serial_port, opcode, FORMAT);
end


function send_drive(serPort, linear_vel, angular_vel)
    % Controls Roomba’s drive wheels using linear and angular velocity
    STRAIGHT_RADIUS = 32768; max_radius = 2000; max_vel = 500;
    radius = round(linear_vel / angular_vel);
    if angular_vel == 0
        radius = STRAIGHT_RADIUS;
    else
        radius = round(linear_vel / angular_vel);
    end

    velocity = int16(max(-max_vel, min(max_vel, linear_vel)));
    radius = int16(max(-max_radius, min(max_radius, radius)));

    vel_h = bitshift(velocity, -8);
    vel_l = bitand(velocity, 255);
    rad_h = bitshift(radius, -8);
    rad_l = bitand(radius, 255);
    write(serPort, [137, vel_h, vel_l, rad_h, rad_l], FORMAT);
end

function play_country_roads(serPort)
    % Plays the song country roads
    unit_time_int = 16; % quarter of a second for every '1'
    first_song_num = 0;
    first_len = 16;
    second_song_num = 1;
    second_len = 10;

    note_mappings = containers.Map();
    note_mappings('A') = 57;
    note_mappings('B') = 59;
    note_mappings('C') = 61; % sharp (key of A)
    note_mappings('E') = 64;
    note_mappings('F') = 66; % sharp (key of A)

    notes_string = 'ABCCABCBACEFFCECCABACBAABA';
    notes_values = [];
    durations = [1 1 3 1 1 3 1 1 3 1 1 3 1 1 1 3 1 1 1 3 1 1 3 1 1 3] * unit_time_int ; % 26 notes

    for i = 1:length(notes_string)
        notes_values(i) = note_mappings(notes_string(i));
    end

    

    
end

play_country_roads()