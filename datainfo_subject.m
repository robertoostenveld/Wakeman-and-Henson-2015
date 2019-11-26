function subj = datainfo_subject(subject, datapath)

if nargin<1 || isempty(subject)
  % this is the default subject
  subject = 15;
end
  
subj_name = sprintf('sub-%02d', subject);

%% specify the root location of all files
if nargin<2 || isempty(datapath)
  f = mfilename('fullpath');
  f = split(f, '/');
  datapath = fullfile('/',f{1:end-2}); % assume that this function lives in a directory one-level down from the datadir
end

%% specify the location of the input and output files

% with the data organized according to BIDS, the sss files are in the
% derivatives folder.
megpath    = fullfile(datapath, 'derivatives', 'meg_derivatives', subj_name, 'ses-meg', 'meg');
mripath    = fullfile(datapath, subj_name, 'ses-mri', 'anat');
eventspath = fullfile(datapath, subj_name, 'ses-meg', 'meg');

outputpath = fullfile(datapath, 'derivatives');
if ~exist(fullfile(outputpath), 'dir')
  mkdir(fullfile(outputpath));
end

subdirs = {'raw2erp' 'sensoranalysis' 'anatomy' 'sourceanalysis' 'groupanalysis'};
for m = 1:numel(subdirs)
  if ~exist(fullfile(outputpath, subdirs{m}), 'dir')
    mkdir(fullfile(outputpath, subdirs{m}));
  end
  if ~exist(fullfile(outputpath, subdirs{m}, subj_name), 'dir')
    mkdir(fullfile(outputpath, subdirs{m}, subj_name));
  end
    
end

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

