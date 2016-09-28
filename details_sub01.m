subject = 1;

%% specify the root location of all files (can be on a network or USB disk)

dataprefix = {
  '/Volumes/BIOMAG2016/biomag2016'
  '/Volumes/128GB/workshop/biomag2016'
  '/project_ext/3010029/biomag2016'
};

for i=1:numel(dataprefix)
  if isdir(dataprefix{i})
    dataprefix = dataprefix{i};
    break
  end % if
end % for

%% specify the location of the input and output files

outputpath = sprintf('%s/processed/Sub%02d', dataprefix, subject);
megpath    = sprintf('%s/raw/Sub%02d/MEEG/', dataprefix, subject);
mripath    = sprintf('%s/raw/Sub%02d/T1/',   dataprefix, subject);

mkdir(outputpath)

%% specify the names of the MEG datasets

megfile = {};
megfile{1} = fullfile(megpath, 'run_01_sss.fif');
megfile{2} = fullfile(megpath, 'run_02_sss.fif');
megfile{3} = fullfile(megpath, 'run_03_sss.fif');
megfile{4} = fullfile(megpath, 'run_04_sss.fif');
megfile{5} = fullfile(megpath, 'run_05_sss.fif');
megfile{6} = fullfile(megpath, 'run_06_sss.fif');

%% specify the name of the anatomical MRI

mrifile = fullfile(mripath, 'mprage.nii');

%% other subject-specific information could also go here, especially if
% it follows from a manual assesment or analysis. Examples are
%  - bad channels
%  - bad data segments
%  - deviations from trigger codes
%  - anatomical information for coregistration

fid = fopen(fullfile(mripath, 'mri_fids.txt'));
column = textscan(fid, '%f %f %f %s');
fclose(fid);

assert(strcmp(column{4}{1}, 'NAS'))
assert(strcmp(column{4}{2}, 'LPA'))
assert(strcmp(column{4}{3}, 'RPA'))

NAS = [column{1}(1) column{2}(1) column{3}(1)];
LPA = [column{1}(2) column{2}(2) column{3}(2)];
RPA = [column{1}(3) column{2}(3) column{3}(3)];

