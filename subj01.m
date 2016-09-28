%%

outputpath = '/Volumes/128GB/workshop//biomag2016/processed/Sub01';
megpath    = '/Volumes/128GB/workshop/biomag2016/raw/Sub01/MEEG/';
mripath    = '/Volumes/128GB/workshop/biomag2016/raw/Sub01/T1/';

mkdir(outputpath)

%%

megfile = {};
megfile{1} = fullfile(megpath, 'run_01_sss.fif');
megfile{2} = fullfile(megpath, 'run_02_sss.fif');
megfile{3} = fullfile(megpath, 'run_03_sss.fif');
megfile{4} = fullfile(megpath, 'run_04_sss.fif');
megfile{5} = fullfile(megpath, 'run_05_sss.fif');
megfile{6} = fullfile(megpath, 'run_06_sss.fif');

%%

mrifile = fullfile(mripath, 'mprage.nii');

fid = fopen(fullfile(mripath, 'mri_fids.txt'));
column = textscan(fid, '%f %f %f %s');
fclose(fid);

assert(strcmp(column{4}{1}, 'NAS'))
assert(strcmp(column{4}{2}, 'LPA'))
assert(strcmp(column{4}{3}, 'RPA'))

NAS = [column{1}(1) column{2}(1) column{3}(1)];
LPA = [column{1}(2) column{2}(2) column{3}(2)];
RPA = [column{1}(3) column{2}(3) column{3}(3)];


