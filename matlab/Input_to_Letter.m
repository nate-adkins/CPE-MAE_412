function letter_matrices = Input_to_Letter()
    prompt= 'input a String ';
    string = upper(input(prompt, 's'));
    string_length= length(string);
    x_extend = 0;
    word_matrix = [];
    for i = 1: string_length
    letter_Matrix = table2array(readLetterCSV(string(i)));
    % disp(letter_Matrix)
    letter_Matrix(:,1) = letter_Matrix(:,1)+ x_extend;
    word_matrix = [word_matrix; letter_Matrix];
    disp(word_matrix)
    x_extend = max(word_matrix(:,1))+10;
    end
letter_matrices = word_matrix;
end

function data = readLetterCSV(letter)
   
    
    % Validate input
    if ~ischar(letter) || length(letter) ~= 1 || ~ismember(letter, 'A':'Z')
        error('Input must be a letter (A-Z).');
    end
    
    % Construct the filename
    filename = strcat('/home/smart1/CPE-MAE_412/path_creator/csv paths/',letter, '.csv');
    
    % Check if the file exists
    if isfile(filename)
        % Read the CSV file
        data = readtable(filename);
        disp(['Successfully read file: ', filename]);
    else
        % Throw an error if the file does not exist
        error('File %s does not exist.', filename);
    end
end

% 