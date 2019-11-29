% this script does channel-level time-frequency analysis

definetrial       = true;
readdata          = true;
dofreq_mtmconvol  = true;
dofreq_wavelet    = true;
doplot            = false;
dofreq_singlechan = false;

%%

if definetrial
  
  trl = cell(6,1);
  for run_nr = 1:6
    hdr   = ft_read_header(subj.megfile{run_nr});
    event = ft_read_event(subj.eventsfile{run_nr}, 'header', hdr, 'eventformat', 'bids_tsv');
    
    trialtype = {event.type}';
    sel       = ismember(trialtype, {'Famous' 'Unfamiliar' 'Scrambled'});
    event     = event(sel);
    
    prestim  = round(0.8.*hdr.Fs);
    poststim = round(1.5.*hdr.Fs)-1;
    
    trialtype = {event.type}';
    trialcode = nan(numel(event),1);
    trialcode(strcmp(trialtype, 'Famous'))     = 1;
    trialcode(strcmp(trialtype, 'Unfamiliar')) = 2;
    trialcode(strcmp(trialtype, 'Scrambled'))  = 3;
    
    begsample = max(round([event.sample]) - prestim,  1);
    endsample = min(round([event.sample]) + poststim, hdr.nSamples);
    offset    = -prestim.*ones(numel(begsample),1);
    
    subj.trl{run_nr} = [begsample(:) endsample(:) offset(:) trialcode(:) ones(numel(begsample),1).*run_nr];
  end
  
end

%%

if readdata
  
  rundata = cell(1,6);
  for run_nr = 1:6
    
    cfg         = [];
    cfg.dataset = subj.megfile{run_nr};
    cfg.trl     = subj.trl{run_nr};
    
    % MEG specific settings
    cfg.channel = 'MEG';
    cfg.demean  = 'yes';
    cfg.coilaccuracy = 0;
    data_meg    = ft_preprocessing(cfg);
    
    cfg            = [];
    cfg.resamplefs = 300;
    data_meg       = ft_resampledata(cfg, data_meg);
    
    rundata{run_nr} = data_meg;
    clear data_meg
  end % for each run
  
  data = ft_appenddata([], rundata{:});
  clear rundata;
  
  filename = fullfile(subj.outputpath, 'sensoranalysis', subj.name, sprintf('%s_data', subj.name));
  save(filename, 'data');
  
end

%%

if dofreq_mtmconvol
  
  filename = fullfile(subj.outputpath, 'sensoranalysis', subj.name, sprintf('%s_data', subj.name));
  load(filename, 'data');
  
  cfg        = [];
  cfg.method = 'mtmconvol';
  cfg.output = 'pow';
  cfg.foi    = 2.5:2.5:30;
  cfg.t_ftimwin = ones(1,numel(cfg.foi)).*0.4;
  cfg.taper  = 'hanning';
  cfg.toi    = (-0.8:0.05:1.3);
  cfg.pad    = 4;
  
  cfg.trials = find(data.trialinfo(:,1)==1);
  freqlow_famous = ft_freqanalysis(cfg, data);
  
  cfg.trials = find(data.trialinfo(:,1)==2);
  freqlow_unfamiliar = ft_freqanalysis(cfg, data);
  
  cfg.trials = find(data.trialinfo(:,1)==3);
  freqlow_scrambled = ft_freqanalysis(cfg, data);
  
  cfg.foi    = 30:5:80;
  cfg.t_ftimwin = ones(1,numel(cfg.foi)).*0.2;
  cfg.tapsmofrq = ones(1,numel(cfg.foi)).*10;
  cfg.taper     = 'dpss';
  
  cfg.trials = find(data.trialinfo(:,1)==1);
  freqhigh_famous = ft_freqanalysis(cfg, data);
  
  cfg.trials = find(data.trialinfo(:,1)==2);
  freqhigh_unfamiliar = ft_freqanalysis(cfg, data);
  
  cfg.trials = find(data.trialinfo(:,1)==3);
  freqhigh_scrambled = ft_freqanalysis(cfg, data);
  
  filename = fullfile(subj.outputpath, 'sensoranalysis', subj.name, sprintf('%s_freq_mtmconvol', subj.name));
  save(filename, 'freqlow_famous', 'freqlow_unfamiliar', 'freqlow_scrambled', 'freqhigh_famous', 'freqhigh_unfamiliar', 'freqhigh_scrambled');
  
end

%%

if dofreq_wavelet
  
  filename = fullfile(subj.outputpath, 'sensoranalysis', subj.name, sprintf('%s_data', subj.name));
  load(filename, 'data');
  
  cfg        = [];
  cfg.method = 'wavelet';
  cfg.output = 'pow';
  cfg.foi    = 1:1:60;
  cfg.width  = 7;
  cfg.toi    = (-0.8:0.05:1.3);
  cfg.pad    = 4;
  
  cfg.trials = find(data.trialinfo(:,1)==1);
  freq_famous = ft_freqanalysis(cfg, data);
  
  cfg.trials = find(data.trialinfo(:,1)==2);
  freq_unfamiliar = ft_freqanalysis(cfg, data);
  
  cfg.trials = find(data.trialinfo(:,1)==3);
  freq_scrambled = ft_freqanalysis(cfg, data);
  
  filename = fullfile(subj.outputpath, 'sensoranalysis', subj.name, sprintf('%s_freq_wavelet', subj.name));
  save(filename, 'freq_famous', 'freq_unfamiliar', 'freq_scrambled');
end

%%

if doplot
  
  cfg = [];
  cfg.baseline     = [-0.6 -0.2];
  cfg.baselinetype = 'absolute';
  cfg.zlim         = [-5e-27 5e-27];
  cfg.showlabels   = 'yes';
  cfg.layout       = 'neuromag306mag_helmet.mat';
  figure; ft_multiplotTFR(cfg, freqlow_famous);
  
  cfg = [];
  cfg.baseline     = [-0.6 -0.2];
  cfg.baselinetype = 'absolute';
  cfg.maskstyle    = 'saturation';
  cfg.zlim         = [-5e-27 5e-27];
  cfg.channel      = 'MEG0731';
  figure; ft_singleplotTFR(cfg, freqlow_famous);
  
  cfg = [];
  cfg.baseline     = [-0.6 -0.2];
  cfg.baselinetype = 'absolute';
  cfg.xlim         = [0.6 0.8];
  cfg.zlim         = [-5e-27 5e-27];
  cfg.ylim         = [4 6];
  cfg.marker       = 'on';
  cfg.layout       = 'neuromag306mag_helmet.mat';
  figure; ft_topoplotTFR(cfg, freqlow_famous);
end

%%

if dofreq_singlechan
  
  cfg              = [];
  cfg.output       = 'pow';
  cfg.channel      = 'MEG0741';
  cfg.method       = 'mtmconvol';
  cfg.taper        = 'hanning';
  cfg.foi          = 2:1:30;
  cfg.t_ftimwin    = 7./cfg.foi;  % 7 cycles per time window
  cfg.toi          = -0.8:0.05:1.5;
  cfg.trials       = find(data.trialinfo(:,1)==1);
  TFRhann7         = ft_freqanalysis(cfg, data);
  cfg.t_ftimwin    = 4./cfg.foi;
  TFRhann4         = ft_freqanalysis(cfg, data);
  cfg.t_ftimwin    = 5./cfg.foi;
  TFRhann5         = ft_freqanalysis(cfg, data);
  cfg.t_ftimwin    = 10./cfg.foi;
  TFRhann10         = ft_freqanalysis(cfg, data);
  
  
  cfg              = [];
  cfg.baseline     = [-0.5 -0.1];
  cfg.baselinetype = 'relchange';
  cfg.maskstyle    = 'saturation';
  cfg.zlim         = [-1 1];
  cfg.channel      = 'MEG0741';
  cfg.interactive  = 'no';
  figure; ft_singleplotTFR(cfg, TFRhann7);
  
end
