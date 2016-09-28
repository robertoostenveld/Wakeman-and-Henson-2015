

outputpath = '/Volumes/128GB/workshop//biomag2016/processed/Sub01';
megpath = '/Volumes/128GB/workshop/biomag2016/raw/Sub01/MEEG/';
mripath = '/Volumes/128GB/workshop/biomag2016/raw/Sub01/T1/';

mkdir('/Volumes/128GB/workshop/biomag2016/processed/Sub01')

megfile = {};
megfile{1} = fullfile(megpath, 'run_01_sss.fif');
megfile{2} = fullfile(megpath, 'run_02_sss.fif');
megfile{3} = fullfile(megpath, 'run_03_sss.fif');
megfile{4} = fullfile(megpath, 'run_04_sss.fif');
megfile{5} = fullfile(megpath, 'run_05_sss.fif');
megfile{6} = fullfile(megpath, 'run_06_sss.fif');

mrifile = fullfile(mripath, 'mprage.nii');

% this is from mri_fids.txt
NAS = [  4.30	119.20	8.30	];
LPA = [-75.30	24.60	-31.90	];
RPA = [ 81.20	20.60	-33.50	];