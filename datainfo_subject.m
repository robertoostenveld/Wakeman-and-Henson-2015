function subj = datainfo_subject(subject, dataprefix)

if nargin<1 || isempty(subject)
  % this is the default subjects
  subject = 15;
end
  
subj_name = sprintf('sub-%02d', subject);

%% specify the root location of all files (can be on a network or USB disk)
if nargin<2 || isempty(dataprefix)
%   dataprefix = {
%     '/Volumes/BIOMAG2016/biomag2016'
%     '/Volumes/128GB/workshop/biomag2016'
%     '/project_ext/3010029/biomag2016'
%     '/project_qnap/3010000.02/practicalMEEG/ds000117'
%     };
%   
%   for i=1:numel(dataprefix)
%     if isdir(dataprefix{i})
%       dataprefix = dataprefix{i};
%       break
%     end % if
%   end % for
  f = mfilename('fullpath');
  f = split(f, '/');
  dataprefix = fullfile('/',f{1:end-2},'ds000117'); % assume that this function lives in a directory one-level down from the ds000117 dir
else
  if ~contains(dataprefix, 'ds000117')
    dataprefix = fullfile(dataprefix, 'ds000117');
  end
end

%% specify the location of the input and output files

%outputpath = sprintf('%s/processed/Sub%02d', dataprefix, subject);
%megpath    = sprintf('%s/raw/Sub%02d/MEEG/', dataprefix, subject);
%mripath    = sprintf('%s/raw/Sub%02d/T1/',   dataprefix, subject);

% with the data organized according to BIDS, the sss files are in the
% derivatives folder.
megpath    = fullfile(dataprefix, 'derivatives', 'meg_derivatives', subj_name, 'ses-meg', 'meg');
mripath    = fullfile(dataprefix, subj_name, 'ses-mri', 'anat');
eventspath = fullfile(dataprefix, subj_name, 'ses-meg', 'meg');

outputpath = fullfile(dataprefix, 'processed', subj_name);

% for now write the results somewhere else than in the main BIDS folder
if contains(outputpath, 'ds000117/'), outputpath = strrep(outputpath, 'ds000117/', ''); end
warning off;mkdir(outputpath);warning on

%% specify the names of the MEG datasets
megfile = cell(6,1);
eventsfile = cell(6,1);
for run_nr = 1:6
  megfile{run_nr}    = fullfile(megpath,    sprintf('%s_ses-meg_task-facerecognition_run-%02d_proc-sss_meg.fif', subj_name, run_nr));
  eventsfile{run_nr} = fullfile(eventspath, sprintf('%s_ses-meg_task-facerecognition_run-%02d_events.tsv', subj_name, run_nr));  
end

%% specify the name of the anatomical MRI -> check whether this works on windows
mrifile = fullfile(mripath, sprintf('%s_ses-mri_acq-mprage_T1w.nii.gz', subj_name));
fidfile = strrep(mrifile, 'nii.gz', 'json');

subj = struct('id',subject,'name',subj_name,'mrifile',mrifile,'fidfile',fidfile,'outputpath',outputpath);
subj.megfile    = megfile;
subj.eventsfile = eventsfile;

%% other subject-specific information could also go here, especially if
% it follows from a manual assesment or analysis. Examples are
%  - bad channels
%  - bad data segments
%  - deviations from trigger codes
%  - anatomical information for coregistration

