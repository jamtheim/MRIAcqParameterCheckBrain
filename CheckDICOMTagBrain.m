function CheckDICOMTagBrain(patientFolder)

%% This functions check the DICOM tags on each DICOM file. The DICOM tags are
% compared to a defined template. This makes sure that the images has been
% aquired with the correct MRI aqusition sequence.
% The script should cover all visable parameters in the MRI protocols that
% have the possibility to be changed.

% Input is tested with DICOM files recieved with ConQuest DICOM server. The
% files has not been anonomized.

%% Version
% 2019-03-14
% Written by Christian Jamtheim Gustafsson, Medical Physicist Expert, PhD
% Skåne University Hospital, Lund, Sweden

%% CHANGELOG
% 2017-02 Creation of script
% 2017-03-13 Added XXX to mailinglist
% 2019-03-14 Change and adaptation to Brain project
% 2020-11-18 Adaptations to DV28 software

%% SET UP ENVIRONMENT
% Define error count variable
errorCount = 0;
% Start with a pause. This is to make sure all data have been succefully
% recieved before starting the analysis. Especially to check if all DIXON data is in place
% Apply only for the session running on the XXX server
 switch version
     case '8.6.0.267246 (R2015b)'
         pause(300)
     otherwise
         pause(1)
end

% Create an folder for keeping track of analysed patients
% If not exist create folder
folderAnalysed = 'Analysed';
if exist(folderAnalysed, 'dir') == 0
    mkdir(folderAnalysed)
end

% Serie to look for in this script
GroundName = ['DIXON IDEAL v1.4']; 
NameThisSeries = ['WATER: ' num2str(GroundName)];

%% OPTIONS FOR EMAIL
setpref('Internet','E_mail','senderemail@domain.se');
setpref('Internet','SMTP_Server','smtpserver.domain.se');
mailReceivers = {'reciever1@domain.se'; 'reciever2@domain.se'; 'reciever3@domain.se'};

%% READ DICOM SERIES
% Load the DICOM data.
% Check if input has been given to the function
% Insert check block for potential memory failures on Win32 systems
try
    
    if  exist('patientFolder','var') == 0
        [import.DicomData, import.DicomInfo, import.patientFolder] = dicomfolder();
    else
        [import.DicomData, import.DicomInfo, import.patientFolder] = dicomfolder(patientFolder);
    end
    
catch
    h = msgbox('Patient could not be loaded', 'Warning', 'warn');
    sendmail(mailReceivers, 'Parameter evaluation for MRI Only Brain failed', ['Parameter evaluation for MRI Only Brain failed. Probably due to memory error in image loading']);
    exit
end


% Convertion to single precision for reserving memory
DicomData.Imported = single(import.DicomData);
% Determine log file name
logfileName = [import.DicomInfo{1}.PatientName.FamilyName '_' num2str(import.DicomInfo{1}.SeriesDate) '_' num2str(import.DicomInfo{1}.SeriesTime) '.txt'];
%%
% Check if the patient alredy has been analysed
% If file does not exist, then run the analysis, else ignore
% if exist(fullfile(pwd,folderAnalysed,logfileName), 'file') == 0 /removed
    
    %% OPEN LOG FILE
    fid = fopen(logfileName, 'a');
    %% PRIOR DATA INTEGRITY CHECK
    % Get number of slices
    numberSlices = size(DicomData.Imported,3);
    % Should be the same as number of locations in acqusition (0021,104F)
    % (not same as Slices per 3D slab, see below)
    if numberSlices ~= import.DicomInfo{1}.Private_0021_104f
        WriteToLogAndDisplay(fid, 'Something is wrong with available number of slices in the recieved data')
        errorCount = errorCount + 1;
    end
    
        % Test to check the validity of SpacingBetweenSlices and SliceThickness and SliceLocation.
        % If errors larger than 0.1 mm exist, throw message.
    if strcmp(num2str(import.DicomInfo{1}.Modality),'MR')
        for i = 0:size(import.DicomInfo,1)-1
            if import.DicomInfo{1}.ImagePositionPatient(3) + i*import.DicomInfo{1}.SpacingBetweenSlices - import.DicomInfo{i+1}.SliceLocation > 0.1
                WriteToLogAndDisplay(fid, 'Something is wrong with the the assumed slice thickness');
                errorCount = errorCount + 1;
            end
        end
    else % For CT
        for i = 0:size(import.DicomInfo,1)-1
            if import.DicomInfo{1}.ImagePositionPatient(3) + i*import.DicomInfo{1}.SliceThickness - import.DicomInfo{i+1}.SliceLocation > 0.1
                WriteToLogAndDisplay(fid, 'Something is wrong with the the assumed slice thickness');
                errorCount = errorCount + 1;
            end
        end
    end    
    %%
    
    %% Check that all DIXON data is available in the patient folder
    % Ger directory list
    % folderList = dir(import.patientFolder); 
    % Check only for one slice, that is enough
    % Remove last folder in path to get path to folder above
    % pathLevelUp = fileparts(folderList(1).folder); 
    pathLevelUp = fileparts(import.patientFolder);    
    % Get directory list from that level
    folderListLevelUp = dir(pathLevelUp); 
    % Set dummy counting variable to 0
    DIXONmatchScore = 0; 
    % Loop through all directories to see that all DIXON data is there
    for i = 1:numel(folderListLevelUp)
        % Name of every folder is given in folderListLevelUp.name
        % Check for 4 directories water, fat, inPhase, outPhase
        searchResults = regexp(folderListLevelUp(i).name,'(WATER__DIXON_IDEAL_v1_4|FAT__DIXON_IDEAL_v1_4|InPhase__DIXON_IDEAL_v1_4|OutPhase__DIXON_IDEAL_v1_4)','match','once');
        switch searchResults
            case 'WATER__DIXON_IDEAL_v1_4'
                DIXONmatchScore = DIXONmatchScore + 1; 
            case 'FAT__DIXON_IDEAL_v1_4'
                DIXONmatchScore = DIXONmatchScore + 1; 
            case 'InPhase__DIXON_IDEAL_v1_4'
                DIXONmatchScore = DIXONmatchScore + 1; 
            case 'OutPhase__DIXON_IDEAL_v1_4'
                DIXONmatchScore = DIXONmatchScore + 1; 
        end
    end
    
    % If not all DIXON data folders were found, send email. There should be
    % 4 DIXON data folders.
    if DIXONmatchScore ~= 4
       WriteToLogAndDisplay(fid, ['Some DIXON data is missing in data archive'])
       errorCount = errorCount + 1; 
    end
   
    %% CHECK THE DICOM  HEADER TAGS
    % Compare the strings in the DICOM header to template values
    % Start try block
    try
        % For all slices
        for i = 1:size(import.DicomInfo,1)
            % Check:
            
            % Modality
            if strcmp(num2str(import.DicomInfo{i}.Modality),'MR') ~= 1
                WriteToLogAndDisplay(fid, ['Modality is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Modality)])
                errorCount = errorCount + 1;
            end
            % System name
            if strcmp(num2str(import.DicomInfo{i}.StationName),'XXX') ~= 1
                WriteToLogAndDisplay(fid, ['StationName is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.StationName)])
                errorCount = errorCount + 1;
            end
            % SW version
            if strcmp(num2str(import.DicomInfo{i}.SoftwareVersion),'28\LX\MR Software release:DV28.0_R05_2034.a') ~= 1
                WriteToLogAndDisplay(fid, ['Software version is not correct, has it been upgraded?. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.SoftwareVersion)])
                errorCount = errorCount + 1;
            end
            % Name of the series 
            if strcmp(num2str(import.DicomInfo{i}.SeriesDescription),NameThisSeries) ~= 1
                WriteToLogAndDisplay(fid, ['SeriesDescription is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.SeriesDescription)])
                errorCount = errorCount + 1;
            end
            % Name of the protocol
            if strcmp(num2str(import.DicomInfo{i}.ProtocolName),'RT_HJARNA + DIXON P+C_v6') ~= 1
                WriteToLogAndDisplay(fid, ['ProtocolName is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ProtocolName)])
                errorCount = errorCount + 1;
            end
            % Name of the MR Model
            if strcmp(num2str(import.DicomInfo{i}.ManufacturerModelName),'SIGNA Architect') ~= 1
                WriteToLogAndDisplay(fid, ['ManufacturerModelName is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ManufacturerModelName)])
                errorCount = errorCount + 1;
            end
            % Check for axial slice orientation
            if import.DicomInfo{i}.ImageOrientationPatient' ~= [1 0 0 0 1 0]
                WriteToLogAndDisplay(fid, ['Slice orientation is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ImageOrientationPatient)])
                errorCount = errorCount + 1;
            end
            % Type of scan sequence. Not sure what RM stands for
            if strcmp(num2str(import.DicomInfo{i}.ScanningSequence),'RM') ~= 1
                WriteToLogAndDisplay(fid, ['ScanningSequence is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ScanningSequence)])
                errorCount = errorCount + 1;
            end
            % Image type (we check water images in this script) 
            if strcmp(num2str(import.DicomInfo{i}.ImageType),'DERIVED\PRIMARY\DIXON\WATER') ~= 1
                WriteToLogAndDisplay(fid, ['ImageType is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ImageType)])
                errorCount = errorCount + 1;
            end
            % Anatomy preference           
            if strcmp(num2str(import.DicomInfo{i}.BodyPartExamined),'BRAIN') ~= 1
                WriteToLogAndDisplay(fid, ['BodyPartExamined is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.BodyPartExamined)])
                errorCount = errorCount + 1;
            end
            % IDEAL option and extended dynamic range 
            if strcmp(num2str(import.DicomInfo{i}.ScanOptions),'EDR_GEMS\IDEAL_GEMS\FILTERED_GEMS\ACC_GEMS') ~= 1
                WriteToLogAndDisplay(fid, ['ScanOptions is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ScanOptions)])
                errorCount = errorCount + 1;
            end
            % Check ASSET R Factors
            if import.DicomInfo{i}.Private_0043_1083' ~= [0.5000 1.0000] 
                WriteToLogAndDisplay(fid, ['Asset R factors is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0043_1083)])
                errorCount = errorCount + 1;
            end
            % Check Pulse sequence type
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_109e),'EFGRE3D') ~= 1
                WriteToLogAndDisplay(fid, ['Pulse sequence type is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_109e)])
                errorCount = errorCount + 1;
            end
            % MR Acquisition mode
            if strcmp(num2str(import.DicomInfo{i}.MRAcquisitionType),'3D') ~= 1
                WriteToLogAndDisplay(fid, ['MRAcquisitionType is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.MRAcquisitionType)])
                errorCount = errorCount + 1;
            end
            % Slice thickness
            if strcmp(num2str(import.DicomInfo{i}.SliceThickness),'2') ~= 1
                WriteToLogAndDisplay(fid, ['SliceThickness is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.SliceThickness)])
                errorCount = errorCount + 1;
            end
            % TR can not be manually changed, test data reports 6.616 ms. 
            if import.DicomInfo{i}.RepetitionTime > 7
                WriteToLogAndDisplay(fid, ['RepetitionTime is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.RepetitionTime)])
                errorCount = errorCount + 1;
            end
            % Echo time. Set to min full. Should not be larger than 3. 
            if import.DicomInfo{i}.EchoTime > 3
                WriteToLogAndDisplay(fid, ['Echo time is too high. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.EchoTime)])
                errorCount = errorCount + 1;
            end
            % NEX
            if strcmp(num2str(import.DicomInfo{i}.NumberOfAverages),'1') ~= 1
                WriteToLogAndDisplay(fid, ['NumberOfAverages is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.NumberOfAverages)])
                errorCount = errorCount + 1;
            end
            % Hydrogen only
            if strcmp(num2str(import.DicomInfo{i}.ImagedNucleus),'1H') ~= 1
                WriteToLogAndDisplay(fid, ['ImagedNucleus is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ImagedNucleus)])
                errorCount = errorCount + 1;
            end
            % Magnetic field strength
            if strcmp(num2str(import.DicomInfo{i}.MagneticFieldStrength),'3') ~= 1
                WriteToLogAndDisplay(fid, ['ImagedNucleus is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ImagedNucleus)])
                errorCount = errorCount + 1;
            end
            % Echo train length
            if strcmp(num2str(import.DicomInfo{i}.EchoTrainLength),'1') ~= 1
                WriteToLogAndDisplay(fid, ['EchoTrainLength is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.EchoTrainLength)])
                errorCount = errorCount + 1;
            end
            % Percent sampling
            if strcmp(num2str(import.DicomInfo{i}.PercentSampling),'100') ~= 1
                WriteToLogAndDisplay(fid, ['PercentSampling is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.PercentSampling)])
                errorCount = errorCount + 1;
            end
            % Percent sampling in phase direction
            if strcmp(num2str(import.DicomInfo{i}.PercentPhaseFieldOfView),'100') ~= 1
                WriteToLogAndDisplay(fid, ['PercentPhaseFieldOfView is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.PercentPhaseFieldOfView)])
                errorCount = errorCount + 1;
            end
            % Pixel bandwidth. Figure is calculated from interpolated 512
            % image. 
            if strcmp(num2str(import.DicomInfo{i}.PixelBandwidth),'325.508') ~= 1
                WriteToLogAndDisplay(fid, ['PixelBandwidth is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.PixelBandwidth)])
                errorCount = errorCount + 1;
            end
            % Field of view
            if strcmp(num2str(import.DicomInfo{i}.ReconstructionDiameter),'240') ~= 1
                WriteToLogAndDisplay(fid, ['ReconstructionDiameter is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ReconstructionDiameter)])
                errorCount = errorCount + 1;
            end
            % Matrix size
            % Order of data is determined by settings in Freq. Dir also. So change
            % in that will be propagated to this parameter also. 
            if import.DicomInfo{i}.AcquisitionMatrix ~= [0; 224; 224; 0]
                WriteToLogAndDisplay(fid, ['AcquisitionMatrix is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.AcquisitionMatrix(1)) ' and ' num2str(import.DicomInfo{i}.AcquisitionMatrix(2)) ' and ' num2str(import.DicomInfo{i}.AcquisitionMatrix(3)) ' and ' num2str(import.DicomInfo{i}.AcquisitionMatrix(4))])
                errorCount = errorCount + 1;
            end
            % Direction of in plane phase encoding direction
            if strcmp(num2str(import.DicomInfo{i}.InPlanePhaseEncodingDirection),'ROW') ~= 1
                WriteToLogAndDisplay(fid, ['InPlanePhaseEncodingDirection is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.InPlanePhaseEncodingDirection)])
                errorCount = errorCount + 1;
            end
            % Flip angle
            if strcmp(num2str(import.DicomInfo{i}.FlipAngle),'12') ~= 1
                WriteToLogAndDisplay(fid, ['FlipAngle is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.FlipAngle)])
                errorCount = errorCount + 1;
            end
            % Number of 3D slabs
            if strcmp(num2str(import.DicomInfo{i}.Private_0021_1056),'1') ~= 1
                WriteToLogAndDisplay(fid, ['Number of 3D slabs might be incorrect. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0021_1056)])
                % errorCount = errorCount + 1;
            end
            % Slices per 3D slab
            % Might vary depending on SAR and WEIGHT, give notice
            if strcmp(num2str(import.DicomInfo{i}.Private_0021_1057),'120') ~= 1
                WriteToLogAndDisplay(fid, ['Locs per 3D slab might be incorrect, check why. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0021_1057)])
                % errorCount = errorCount + 1;
            end
            % Rows in output matrix
            if strcmp(num2str(import.DicomInfo{i}.Rows),'512') ~= 1
                WriteToLogAndDisplay(fid, ['Rows is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Rows)])
                errorCount = errorCount + 1;
            end
            % Columns in output matrix
            if strcmp(num2str(import.DicomInfo{i}.Columns),'512') ~= 1
                WriteToLogAndDisplay(fid, ['Columns is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Columns)])
                errorCount = errorCount + 1;
            end
            % Output pixel resolution
            if import.DicomInfo{i}.PixelSpacing ~= [0.4688; 0.4688]
                WriteToLogAndDisplay(fid, ['PixelSpacing is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.PixelSpacing(1)) ' and ' num2str(import.DicomInfo{i}.PixelSpacing(2)) ])
                errorCount = errorCount + 1;
            end
            % Check if the distance between spaces is 0 by comparing 2 values
            if import.DicomInfo{i}.SliceThickness-import.DicomInfo{i}.SpacingBetweenSlices ~= 0
                WriteToLogAndDisplay(fid, ['Slice Spacing isn not correct. Value for slice ' num2str(i) ' was not 0'])
                errorCount = errorCount + 1;
            end
           % 3D Distortion correction, filter setting and SCIC. (w and s are put together)
            if strcmp(num2str(import.DicomInfo{i}.Private_0043_102d),'wsb') ~= 1
                WriteToLogAndDisplay(fid, ['3D distortion correction, image intensity correction or image filtering is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0043_102d)])
                errorCount = errorCount + 1;
            end
            % Phase correct and Shim
            % Bitmap of prescan options.
            % Phase correct = off, (0043,1001) = 4
            % Shim = off, (0043,1001) = 2
            % Phase correct = on and Shim = Auto, (0043,1001) = 6 
            % Phase correct = off and Shim = Auto, (0043,1001) = 4 
            if strcmp(num2str(import.DicomInfo{i}.Private_0043_1001),'4') ~= 1
                WriteToLogAndDisplay(fid, ['Phase correct and/or shim is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0043_1001)])
                errorCount = errorCount + 1;
            end
            %  RF Drive mode
            % Specific tag not detected but change was found in tagg (0043,10A8)
            % Dual Drive Mode, Amplitude Attenuation and Phase Offset
            % RF drive mode = preset (0043,10A8) = 2\30\-30
            % RF drive mode = quadrature (0043,10A8)= 1\0\0
            if import.DicomInfo{i}.Private_0043_10a8 ~= [1; 0; -0;]
                WriteToLogAndDisplay(fid, ['RF Drive mode is not correct.'])
                errorCount = errorCount + 1;
            end
            % Table delta
            if import.DicomInfo{i}.Private_0019_107f ~= 0
                WriteToLogAndDisplay(fid, ['Table delta is not correct.'])
                errorCount = errorCount + 1;
            end
            % Chech for correct coil setup
			% Removed in DV28 adaptations. Tag seem to be moved. 
            %if strcmp(num2str(import.DicomInfo{i}.Private_0043_1081),'C-GEMRTHead') ~= 1
            %    WriteToLogAndDisplay(fid, ['Coil setup is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0043_1081)])
            %    errorCount = errorCount + 1;
            %end
           % First level SAR
             if strcmp(num2str(import.DicomInfo{i}.Private_0043_1089),'IEC\IEC_FIRST_LEVEL\IEC_FIRST_LEVEL') ~= 1
                WriteToLogAndDisplay(fid, ['SAR mode is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0043_1089)])
                errorCount = errorCount + 1;
             end


            %% Parameters that can be changed in the protocol advanced page (NOT FINISHED) 
            
            % CV4. Image acq. delay (not found in DICOM conformance
            % statement document, check by difference in DICOM headers) 
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_10ab),'0') ~= 1
                WriteToLogAndDisplay(fid, ['Image acq. delay is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_10AB)])
                errorCount = errorCount + 1;
            end
            % CV6 Turbo Mode
             if strcmp(num2str(import.DicomInfo{i}.Private_0019_10ad),'2') ~= 1
                WriteToLogAndDisplay(fid, ['Turbo mode is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_10AD)])
                errorCount = errorCount + 1;
            end
            % CV 23 Slice resolution
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_10df),'100') ~= 1
                WriteToLogAndDisplay(fid, ['Slice resolution is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_10DF)])
                errorCount = errorCount + 1;
            end
            
        end
        
    catch
        errorCount = errorCount + 1;
        h  = msgbox('Seems that some tags can not be read or are missing', 'Error','error');
    end
    
    %% Check the error status and alert by email
    if errorCount > 0
        WriteToLogAndDisplay(fid, [ num2str(errorCount) ' protocol error(s) were found in total for all slices'])
        % It is important that this row is at the end of the file. This is
        % being read by the Eclipse check script. Richard Cronholm manages
        % that script. 
        WriteToLogAndDisplay(fid, 'Line below must not be changed. This is matched in the Eclipse check script.')
        WriteToLogAndDisplay(fid, 'MRI SYNTHETIC CT PARAMETERS NOT OK')
        % WriteToLogAndDisplay(fid, ['It is estimated that ' num2str(errorCount/size(DicomData.Imported,3)) ' parameters were wrong'])
        h = msgbox('Parameters did not match', 'Error', 'error');
        statusCheck = ['Fail'];
        % Close file write
        fclose(fid);
        % Send email
        sendmail(mailReceivers, 'Fail', ['MRI Only Brain protocol parameters was not correct for patient ' import.DicomInfo{1}.PatientName.FamilyName ' with image acqusition performed on ' num2str(import.DicomInfo{1}.SeriesDate) ' ' num2str(import.DicomInfo{1}.SeriesTime)], logfileName);
    else
        % It is important that this row is at the end of the file. This is
        % being read by the Eclipse check script. 
        statusCheck = ['OK'];
        WriteToLogAndDisplay(fid, 'Line below must not be changed. This is matched in the Eclipse check script.')
        WriteToLogAndDisplay(fid, 'MRI SYNTHETIC CT PARAMETERS OK')
        h = msgbox('Acqusition parameters are OK','Success');
        % Close file write
        fclose(fid);
        % Send email
        sendmail(mailReceivers, 'Success', ['MRI Only Brain protocol parameters was OK for patient ' import.DicomInfo{1}.PatientName.FamilyName ' with image acqusition performed on ' num2str(import.DicomInfo{1}.SeriesDate) ' ' num2str(import.DicomInfo{1}.SeriesTime)], logfileName);
    end

    %% MOVE LOG FILE
    % OLD
    % movefile(logfileName,['./' folderAnalysed])
    % When using movefile file permissions for sharing is not propagated
    % correctly. 
    % Use Copy file for this matter to solve the problem.
   % copyfile(logfileName,['./' folderAnalysed])
   copyfile(logfileName,['\\serverIPAdress\Analysed'])
   % Then delete file
   delete(logfileName)
    
    % To do if patient has been analysed before /removed
% else
    % display('Patient has already been analysed')
    % h = msgbox('Patient has already been analysed', 'Warning', 'warn');
    % sendmail(mailReceivers, 'Status quo', ['MRI Only Brain patient has previously been analysed. Patient ' import.DicomInfo{1}.PatientName.FamilyName ' with image acqusition performed on ' num2str(import.DicomInfo{1}.SeriesDate) ' ' num2str(import.DicomInfo{1}.SeriesTime)]);
    % End of statement for checking if patient already has been analysed
    % /removed
% end

% As this script will run in an automated fashion, it needs to be closed to
% save memory. Therefore execute quit command if version is R2015b which is
% the one running on the sfarkiv server
switch version
    case '8.6.0.267246 (R2015b)'
        quit
    otherwise
        display('Program is done')
end


% END


