definetrial = false;
readdata    = true;
dotimelock  = true;

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
    
    trl = [begsample(:) endsample(:) offset(:) trialcode(:) ones(numel(begsample),1).*run_nr];
    
    filename = fullfile(subj.outputpath, 'raw2erp', sprintf('%s_trl_run%02d', subj.name, run_nr));
    save(filename, 'trl');
    clear trl;
  end
  
end

if readdata
  
  rundata = cell(1,6);
  for run_nr = 1:6
    filename = fullfile(subj.outputpath, 'raw2erp', sprintf('%s_trl_run%02d', subj.name, run_nr));
    load(filename);
    
    cfg         = [];
    cfg.dataset = subj.megfile{run_nr};
    cfg.trl     = trl;
    
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
    cfg.channel    = 'EEG';
    cfg.demean     = 'yes';
    cfg.reref      = 'yes';
    cfg.refchannel = 'all'; % average reference
    data_eeg       = ft_preprocessing(cfg);
    
    % settings for all other channels
    cfg.channel = {'all', '-MEG', '-EEG'};
    cfg.demean  = 'no';
    cfg.reref   = 'no';
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
  
  filename = fullfile(subj.outputpath, 'raw2erp', sprintf('%s_data', subj.name));
  save(filename, 'data');
  
end

if dotimelock
 
  filename = fullfile(subj.outputpath, 'raw2erp', sprintf('%s_data', subj.name));
  load(filename, 'data');
  
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

  filename = fullfile(subj.outputpath, 'raw2erp', sprintf('%s_timelock', subj.name));
  save(filename, 'avg_famous', 'avg_unfamiliar', 'avg_scrambled', 'avg_faces');
  
end
