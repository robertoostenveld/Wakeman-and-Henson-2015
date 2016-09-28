do_explore        = false;
do_anatomy        = false;
do_preprocessing  = true;
do_artefacts      = false;
do_timelock       = false;
do_frequency      = false;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Reading and converting the original data files

% the data set consists of MEG, EEG and anatomical MRI
% furthermore there is functional MRI, but that is not considered here

if do_anatomy
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% Reading and reviewing the anatomical MRI

  mri = ft_read_mri(mrifile);
  ft_determine_coordsys(mri, 'interactive', false);
  
  save(fullfile(outputpath, 'mri'), 'mri');
  
  if do_explore
    grad = ft_read_sens(megfile{1}, 'senstype', 'meg');
    elec = ft_read_sens(megfile{1}, 'senstype', 'eeg');
    headshape = ft_read_headshape(megfile{1});
    
    figure
    ft_plot_sens(grad, 'unit', 'mm');
    ft_plot_sens(elec, 'unit', 'mm');
    ft_plot_headshape(headshape, 'unit', 'mm');
    ft_plot_axes(headshape, 'unit', 'mm');
    
    cfg = [];
    cfg.locationcoordinates ='head';
    cfg.location = NAS;
    ft_sourceplot(cfg, mri);
    cfg.location = LPA;
    ft_sourceplot(cfg, mri);
    cfg.location = RPA;
    ft_sourceplot(cfg, mri);
  end % do explore
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% Aligning the MEG channel locations and the anatomy
  
  cfg = [];
  cfg.method = 'fiducial';
  cfg.coordsys = 'neuromag';
  cfg.fiducial.nas = ft_warp_apply(inv(mri.transform), NAS);
  cfg.fiducial.lpa = ft_warp_apply(inv(mri.transform), LPA);
  cfg.fiducial.rpa = ft_warp_apply(inv(mri.transform), RPA);
  cfg.inputfile = fullfile(outputpath, 'mri');
  cfg.outputfile = fullfile(outputpath, 'mri_realigned');
  mri_realigned = ft_volumerealign(cfg);
  
  cfg = [];
  cfg.inputfile = fullfile(outputpath, 'mri_realigned');
  cfg.outputfile = fullfile(outputpath, 'mri_resliced');
  mri_resliced = ft_volumereslice(cfg);
  
  % do another check on the coregistration
  ft_determine_coordsys(mri_realigned, 'interactive', false);
  ft_plot_sens(grad, 'unit', 'mm', 'edgecolor', 'm');
  ft_plot_sens(elec, 'unit', 'mm');
  ft_plot_headshape(headshape, 'unit', 'mm');
  view([1 0 0])
  
  % save the figure for quality control
  print('-dpng', fullfile(outputpath, 'coregistration.png'));
  
end % do anatomy

if do_explore
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% Reading and reviewing the functional data

  cfg = [];
  cfg.dataset = megfile{1};
  cfg.channel = 'MEG';
  cfg.viewmode = 'vertical';
  cfg.layout = 'neuromag306all.lay';
  ft_databrowser(cfg);

end % do explore

if do_preprocessing
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% Aligning the MEG time course data with perception and behavior
  
  % We want to create three categories of events, based on their numerical codes:
  % Famous faces:      5 (00101),  6 (00110),  7 (00111) => Bit 3 only
  % Unfamiliar faces: 13 (01101), 14 (01110), 15 (01111) => Bit 3 and 4
  % Scrambled images: 17 (10001), 18 (10010), 19 (10011) => Bit 5 only
  
  % the MEG+EEG data is acquired in 6 blocks, each represented in a single file
  
  block = {};
  for i=1:6
    
    cfg = [];
    cfg.dataset = megfile{i};
    
    cfg.trialfun = 'ft_trialfun_general';
    cfg.trialdef.eventtype = 'STI101';
    cfg.trialdef.eventvalue = [5 6 7 13 14 15 17 18 19];
    cfg.trialdef.prestim  = 0.5;
    cfg.trialdef.poststim = 1.2;
    
    cfg = ft_definetrial(cfg);
    
    famous     = ismember(cfg.trl(:,4), [ 5  6  7]);
    unfamiliar = ismember(cfg.trl(:,4), [13 14 15]);
    scrambled  = ismember(cfg.trl(:,4), [17 18 19]);
    
    % add another column that codes for the three classes
    cfg.trl(famous,    5) = 1;
    cfg.trl(unfamiliar,5) = 2;
    cfg.trl(scrambled, 5) = 3;
    
    % cfg.channel = 'all';
    % cfg.channel = 'megmag';
    % cfg.channel = 'eeg';
    cfg.channel = 'meggrad';
    cfg.baselinewindow = [-inf 0];
    cfg.demean = 'yes';
    block{i} = ft_preprocessing(cfg);
    
  end
  
  % show the two different types of trial codes
  disp(block{1}.trialinfo);
  
  % combine all six blocks into a single
  cfg = [];
  cfg.outputfile = fullfile(outputpath, 'raw');
  raw = ft_appenddata(cfg, block{:});
  
  clear block
  
  %% deal with maxfiltering
  
  % the data has been maxfiltered and subsequently contatenated
  % this will result in an ill-conditioned estimate of covariance or CSD
  
  cfg = [];
  cfg.method = 'pca';
  cfg.updatesens = 'no';
  cfg.channel = 'meggrad';
  cfg.inputfile = fullfile(outputpath, 'raw');
  cfg.outputfile = fullfile(outputpath, 'comp');
  comp = ft_componentanalysis(cfg);
  
  cfg = [];
  cfg.updatesens = 'no';
  cfg.component = comp.label(51:end);
  cfg.inputfile = fullfile(outputpath, 'comp');
  cfg.outputfile = fullfile(outputpath, 'raw_subspace');
  raw_subspace = ft_rejectcomponent(cfg);
  
  cfg = [];
  cfg.baselinewindow = [-inf 0];
  cfg.demean = 'yes';
  cfg.inputfile = fullfile(outputpath, 'raw_subspace');
  cfg.outputfile = fullfile(outputpath, 'raw_subspace_demean');
  raw_subspace_demean = ft_preprocessing(cfg);
  
end % do preprocessing

if do_artefacts
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% Data reviewing and artifact handling
  
  % start with a copy, iterate multiple times
  load(fullfile(outputpath, 'raw_subspace_demean'));
  raw_clean = data;
  save(fullfile(outputpath, 'raw_clean'), 'raw_clean');
  
  cfg = [];
  cfg.keeptrial = 'no';
  cfg.keepchannel = 'yes';
  
  cfg.channel = 'meggrad';
  cfg.inputfile = fullfile(outputpath, 'raw_clean');
  cfg.outputfile = fullfile(outputpath, 'raw_clean');
  raw_clean = ft_rejectvisual(cfg);
  
  % cfg.channel = 'megmag';
  % cfg.inputfile = fullfile(outputpath, 'raw_clean');
  % cfg.outputfile = fullfile(outputpath, 'raw_clean');
  % raw_clean = ft_rejectvisual(cfg);
  
  % cfg.channel = 'eeg';
  % cfg.inputfile = fullfile(outputpath, 'raw_clean');
  % cfg.outputfile = fullfile(outputpath, 'raw_clean');
  % raw_clean = ft_rejectvisual(cfg);
  
end % do artefacts

if do_timelockanalysis
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% Averaging and Event-Related Fields
  
  % famous     = 1
  % unfamiliar = 2
  % scrambled  = 3
  
  cfg = [];
  cfg.inputfile = fullfile(outputpath, 'raw_clean');
  
  cfg.trials = find(raw_clean.trialinfo(:,2)==1);
  cfg.outputfile = fullfile(outputpath, 'timelock_famous');
  timelock_famous = ft_timelockanalysis(cfg);
  
  cfg.trials = find(raw_clean.trialinfo(:,2)==2);
  cfg.outputfile = fullfile(outputpath, 'timelock_unfamiliar');
  timelock_unfamiliar = ft_timelockanalysis(cfg);
  
  cfg.trials = find(raw_clean.trialinfo(:,2)==3);
  cfg.outputfile = fullfile(outputpath, 'timelock_scrambled');
  timelock_scrambled = ft_timelockanalysis(cfg);
  
  cfg.trials = find(raw_clean.trialinfo(:,2)==1 | raw_clean.trialinfo(:,2)==2);
  cfg.outputfile = fullfile(outputpath, 'timelock_faces');
  timelock_faces = ft_timelockanalysis(cfg);
  
  %% Visualization
  
  cfg = [];
  cfg.layout = 'neuromag306planar';
  ft_multiplotER(cfg, timelock_faces, timelock_scrambled);
  ft_multiplotER(cfg, timelock_famous, timelock_unfamiliar);
  
  timelock_famous_cmb      = ft_combineplanar(cfg, timelock_famous);
  timelock_unfamiliar_cmb  = ft_combineplanar(cfg, timelock_unfamiliar);
  timelock_scrambled_cmb   = ft_combineplanar(cfg, timelock_scrambled);
  timelock_faces_cmb       = ft_combineplanar(cfg, timelock_faces);
  
  cfg = [];
  cfg.layout = 'neuromag306cmb';
  ft_multiplotER(cfg, timelock_famous_cmb, timelock_unfamiliar_cmb, timelock_scrambled_cmb);
  
  %% Look at contrasts
  
  cfg = [];
  cfg.parameter = 'avg';
  cfg.operation = 'x1-x2';
  faces_vs_scrambled   = ft_math(cfg, timelock_faces, timelock_scrambled);
  famous_vs_unfamiliar = ft_math(cfg, timelock_famous, timelock_unfamiliar);
  
  faces_vs_scrambled_cmb   = ft_combineplanar(cfg, faces_vs_scrambled);
  famous_vs_unfamiliar_cmb = ft_combineplanar(cfg, famous_vs_unfamiliar);
  
  % note that there is a confound due to the number of trials!!
  
  cfg = [];
  cfg.layout = 'neuromag306cmb';
  figure
  ft_multiplotER(cfg, faces_vs_scrambled_cmb);
  
  figure
  ft_multiplotER(cfg, famous_vs_unfamiliar_cmb);
  
end % do timelockanalysis

if do_frequencyanalysis
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% Time-frequency analysis
  
  cfg = [];
  cfg.method = 'wavelet';
  cfg.width = 5;
  cfg.gwidth = 2;
  cfg.keeptrials = 'yes';
  cfg.toi = -0.5:0.02:1.2;
  cfg.foi = 2:2:50;
  cfg.inputfile = fullfile(outputpath, 'raw_clean');
  cfg.outputfile = fullfile(outputpath, 'freq');
  freq = ft_freqanalysis(cfg);
  
  % compute selective averages
  
  cfg = [];
  cfg.inputfile = fullfile(outputpath, 'freq');
  
  cfg.trials = find(freq.trialinfo(:,2)==1);
  cfg.outputfile = fullfile(outputpath, 'freq_famous');
  freq_famous = ft_freqdescriptives(cfg, freq);
  
  cfg.trials = find(freq.trialinfo(:,2)==2);
  cfg.outputfile = fullfile(outputpath, 'freq_unfamiliar');
  freq_unfamiliar = ft_freqdescriptives(cfg, freq);
  
  cfg.trials = find(freq.trialinfo(:,2)==3);
  cfg.outputfile = fullfile(outputpath, 'freq_scrambled');
  freq_scrambled = ft_freqdescriptives(cfg, freq);
  
  cfg.trials = find(freq.trialinfo(:,2)==1 | freq.trialinfo(:,2)==1);
  cfg.outputfile = fullfile(outputpath, 'freq_faces');
  freq_faces = ft_freqdescriptives(cfg, freq);
  
  %% Visualization
  
  cfg = [];
  freq_famous_cmb     = ft_combineplanar(cfg, freq_famous);
  freq_unfamiliar_cmb = ft_combineplanar(cfg, freq_unfamiliar);
  freq_scrambled_cmb  = ft_combineplanar(cfg, freq_scrambled);
  freq_faces_cmb      = ft_combineplanar(cfg, freq_faces);
  
  cfg = [];
  cfg.layout = 'neuromag306cmb';
  cfg.baseline = [-inf 0];
  cfg.baselinetype = 'relchange';
  figure
  ft_multiplotTFR(cfg, freq_famous_cmb);
  
  figure
  ft_multiplotTFR(cfg, freq_unfamiliar_cmb);
  
  figure
  ft_multiplotTFR(cfg, freq_scrambled_cmb);
  
  figure
  ft_multiplotTFR(cfg, freq_faces_cmb);
  
end % do frequencyanalysis

