definetrial = true;
readdata    = true;
dotimelock  = true;
doplot      = false;
writeflag   = true;

if ~exist('subj', 'var')
  error('specify a subject by calling subj=datainfo_subject(<number>)');
end

% this chunk of code creates the trl matrix per run.
if definetrial
  
  trl = cell(6,1);
  for run_nr = 1:6
    hdr   = ft_read_header(subj.megfile{run_nr});
    event = ft_read_event(subj.eventsfile{run_nr}, 'header', hdr, 'eventformat', 'bids_tsv');
    
    trialtype = {event.type}';
    sel       = ismember(trialtype, {'Famous' 'Unfamiliar' 'Scrambled'});
    event     = event(sel);
    
    prestim  = round(0.5.*hdr.Fs);
    poststim = round(1.2.*hdr.Fs-1);
    
    trialtype = {event.type}';
    trialcode = nan(numel(event),1);
    trialcode(strcmp(trialtype, 'Famous'))     = 1;
    trialcode(strcmp(trialtype, 'Unfamiliar')) = 2;
    trialcode(strcmp(trialtype, 'Scrambled'))  = 3;
    
    begsample = max(round([event.sample]) - prestim,  1);
    endsample = min(round([event.sample]) + poststim, hdr.nSamples);
    offset    = -prestim.*ones(numel(begsample),1);
    
    subj.trl{run_nr} = [begsample(:) endsample(:) offset(:) trialcode(:) ones(numel(begsample),1).*run_nr];
    clear trl;
  end
  
end

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
    cfg.bpfilter = 'yes';
    cfg.bpfilttype = 'firws';
    cfg.bpfreq  = [1 40];
    cfg.padding = 3;
    data_meg    = ft_preprocessing(cfg);
    
    % EEG specific settings
    cfg.channel    = {'EEG' '-EEG061' '-EEG062' '-EEG063' '-EEG064'}; % exclude EOG/ECG/etc hard coded assumed to be this list
    cfg.demean     = 'yes';
    cfg.reref      = 'yes';
    cfg.refchannel = 'all'; % average reference
    data_eeg       = ft_preprocessing(cfg);
    
    % settings for all other channels
    cfg.channel = {'all', '-MEG', '-EEG'};
    cfg.demean  = 'no';
    cfg.reref   = 'no';
    cfg.bpfilter = 'no';
    data_other  = ft_preprocessing(cfg);
    
    cfg            = [];
    cfg.resamplefs = 300;
    data_meg       = ft_resampledata(cfg, data_meg);
    data_eeg       = ft_resampledata(cfg, data_eeg);
    data_other     = ft_resampledata(cfg, data_other);
    
    %% append the different channel sets into a single structure
    rundata{run_nr} = ft_appenddata([], data_meg, data_eeg, data_other);
    clear data_meg data_eeg data_other
  end % for each run
  
  data = ft_appenddata([], rundata{:});
  clear rundata;
  
  if writeflag
    filename = fullfile(subj.outputpath, 'raw2erp', subj.name, sprintf('%s_data', subj.name));
    save(filename, 'data');
  end
  
end

if dotimelock
  
  if ~readdata
    % get the precomputed data
    filename = fullfile(subj.outputpath, 'raw2erp', subj.name, sprintf('%s_data', subj.name));
    load(filename, 'data');
  end
  
  cfg        = [];
  cfg.trials = find(data.trialinfo(:,1)==1);
  cfg.preproc.demean = 'yes';
  cfg.preproc.baselinewindow = [-0.1 0];
  avg_famous = ft_timelockanalysis(cfg, data);
  cfg.trials = find(data.trialinfo(:,1)==2);
  avg_unfamiliar = ft_timelockanalysis(cfg, data);
  
  cfg.trials = find(data.trialinfo(:,1)==3);
  avg_scrambled = ft_timelockanalysis(cfg, data);
  
  cfg.trials = find(data.trialinfo(:,1)==1 | data.trialinfo(:,1)==2);
  avg_faces  = ft_timelockanalysis(cfg, data);
   
  if writeflag
    filename = fullfile(subj.outputpath, 'raw2erp', subj.name, sprintf('%s_timelock', subj.name));
    save(filename, 'avg_famous', 'avg_unfamiliar', 'avg_scrambled', 'avg_faces');
  end
  
end

if doplot

  if ~dotimelock
    filename = fullfile(subj.outputpath, 'raw2erp', subj.name, sprintf('%s_timelock', subj.name));
    load(filename, 'avg_famous', 'avg_unfamiliar', 'avg_scrambled', 'avg_faces');
  end
  
  % visualise the magnetometer data
  cfg        = [];
  cfg.layout = 'neuromag306mag_helmet.mat';
  figure;ft_multiplotER(cfg, avg_famous, avg_unfamiliar, avg_scrambled);
  
  % combine planar gradients and visualise the gradiometer data
  cfg              = [];
  avg_faces_c      = ft_combineplanar(cfg, avg_faces);
  avg_famous_c     = ft_combineplanar(cfg, avg_famous);
  avg_unfamiliar_c = ft_combineplanar(cfg, avg_unfamiliar);
  avg_scrambled_c  = ft_combineplanar(cfg, avg_scrambled);
  
  cfg        = [];
  cfg.layout = 'neuromag306cmb_helmet.mat';
  figure;ft_multiplotER(cfg, avg_famous_c, avg_unfamiliar_c, avg_scrambled_c);
  
  % create an EEG channel layout on-the-fly and visualise the eeg data
  cfg      = [];
  cfg.elec = avg_faces.elec;
  layout_eeg = ft_prepare_layout(cfg);
  
  cfg        = [];
  cfg.layout = layout_eeg;
  figure;ft_multiplotER(cfg, avg_famous, avg_unfamiliar, avg_scrambled);
  
  % alternatively, it is possible to show the different channel types in a
  % single figure, this allows for interacting simultaneously with the
  % different representation. For the colormap to work, the data needs to
  % be scaled per type of data.
  cfg        = [];
  cfg.layout = 'neuromag306mag_helmet.mat';
  layout_mag = ft_prepare_layout(cfg);
  cfg.layout = 'neuromag306cmb_helmet.mat';
  layout_cmb = ft_prepare_layout(cfg);
  
  % in order for this to work, the positions should be in the same order of
  % magnitude
  shiftval = min(layout_eeg.pos(1:70,:),[],1);
  layout_eeg.pos = layout_eeg.pos - repmat(shiftval, numel(layout_eeg.label), 1);
  layout_eeg.mask{1} = layout_eeg.mask{1} - repmat(shiftval, size(layout_eeg.mask{1},1), 1);
  for k = 1:numel(layout_eeg.outline)
    layout_eeg.outline{k} = layout_eeg.outline{k} - repmat(shiftval, size(layout_eeg.outline{k},1), 1);
  end
  
  scaleval = max(layout_eeg.pos(1:70,:),[],1)./500;
  layout_eeg.pos = layout_eeg.pos ./ repmat(scaleval, numel(layout_eeg.label), 1);
  layout_eeg.mask{1} = layout_eeg.mask{1} ./ repmat(scaleval, size(layout_eeg.mask{1},1), 1);
  for k = 1:numel(layout_eeg.outline)
    layout_eeg.outline{k} = layout_eeg.outline{k} ./ repmat(scaleval, size(layout_eeg.outline{k},1), 1);
  end
  
  layout_eeg.width(:)  = 64;
  layout_eeg.height(:) = 48;
  
  cfg = [];
  cfg.distance = 180;
  layout = ft_appendlayout(cfg, ft_appendlayout([], layout_mag, layout_cmb), layout_eeg);
  
  cfg = [];
  cfg.layout = layout;
  cfg.gridscale = 150;
  cfg.magscale  = 0.25e14;
  cfg.gradscale = 1e12;
  cfg.eegscale  = 1e6;
  figure;ft_multiplotER(cfg, avg_famous_c, avg_unfamiliar_c, avg_scrambled_c);
    
end
