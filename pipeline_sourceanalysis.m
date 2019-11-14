doforward  = true;
dolcmv     = true;
dovirtchan = true;
doparcellate = true;
if doforward
  
  % obtain the necessary ingredients for obtaining a forward model
  load(fullfile(subj.outputpath, 'anatomy', sprintf('%s_headmodel', subj.name)));
  load(fullfile(subj.outputpath, 'anatomy', sprintf('%s_sourcemodel', subj.name)));
  headmodel   = ft_convert_units(headmodel,   'm');
  sourcemodel = ft_convert_units(sourcemodel, 'm');
  sourcemodel.inside = sourcemodel.atlasroi>0;
  
  filename = fullfile(subj.outputpath, 'raw2erp', sprintf('%s_data', subj.name));
  load(filename, 'data');
  
  % select the electrophysiological channels
  cfg         = [];
  cfg.channel = {'MEG' 'EEG'};
  data        = ft_selectdata(cfg, data);
  
  % select the 'baseline'
  cfg         = [];
  cfg.latency = [-0.2 0];
  baseline    = ft_selectdata(cfg, data);
  
  % compute the baseline covariance
  cfg            = [];
  cfg.covariance = 'yes';
  baseline_avg   = ft_timelockanalysis(cfg, baseline);
  
  selmag  = ft_chantype(baseline_avg.label, 'megmag');
  selgrad = ft_chantype(baseline_avg.label, 'megplanar');
  seleeg  = ft_chantype(baseline_avg.label, 'eeg');
  
  [u,s_mag,v]  = svd(baseline_avg.cov(selmag,  selmag));
  [u,s_grad,v] = svd(baseline_avg.cov(selgrad, selgrad));
  [u,s_eeg,v]  = svd(baseline_avg.cov(seleeg,  seleeg));
  
  d_mag = -diff(log10(diag(s_mag))); d_mag = d_mag./std(d_mag);
  kappa_mag = find(d_mag>4,1,'first');
  d_grad = -diff(log10(diag(s_grad))); d_grad = d_grad./std(d_grad);
  kappa_grad = find(d_grad>4,1,'first');
  d_eeg = -diff(log10(diag(s_eeg))); d_eeg = d_eeg./std(d_eeg);
  kappa_eeg = find(d_eeg>4,1,'first');
    
  cfg            = [];
  cfg.channel    = 'meg';
  cfg.kappa      = min(kappa_mag,kappa_grad);
  dataw_meg      = ft_denoise_prewhiten(cfg, data, baseline_avg);
  cfg.kappa      = kappa_eeg;
  dataw_eeg      = ft_denoise_prewhiten(cfg, data, baseline_avg);
  
  cfg             = [];
  cfg.channel     = dataw_meg.label;
  cfg.sourcemodel = sourcemodel;
  cfg.headmodel   = headmodel;
  cfg.method      = 'singleshell';
  cfg.singleshell.batchsize = 1000;
  leadfield_meg   = ft_prepare_leadfield(cfg, dataw_meg);
end

if dolcmv
  
  if ~exist('leadfield_meg', 'var')
    error('the forward computation step needs to be performed in order to do inverse modelling');
  end
  
  cfg                = [];
  cfg.preproc.baselinewindow = [-0.2 0];
  cfg.preproc.demean = 'yes';
  cfg.covariance     = 'yes';
  tlckw              = ft_timelockanalysis(cfg, dataw_meg);
  
  [u,s,v] = svd(tlckw.cov);
  d       = -diff(log10(diag(s)));
  d       = d./std(d);
  kappa   = find(d>5,1,'first');
 
  cfg                 = [];
  cfg.method          = 'lcmv';
  cfg.lcmv.kappa      = kappa;
  cfg.lcmv.keepfilter = 'yes';
  cfg.lcmv.fixedori   = 'yes';
  cfg.lcmv.weightnorm = 'unitnoisegain';
  cfg.lcmv.projectnoise = 'yes';
  cfg.headmodel = headmodel;
  cfg.sourcemodel = leadfield_meg;
  source = ft_sourceanalysis(cfg, tlckw);
  
  filename = fullfile(subj.outputpath, 'sourceanalysis', sprintf('%s_source_lcmv', subj.name));
  save(filename, 'source', 'tlckw');
end

if dovirtchan
   
  if ~exist('source', 'var') || ~exist('dataw_meg', 'var')
    error('the forward modelling and lcmv steps need to be performed in order to do inverse modelling');
  end
 
  mom = cat(1,source.avg.mom{:});
  
  sel = nearest(source.time,[0.15 0.2]);
  M   = zeros(size(sourcemodel.pos,1),1);
  M(sourcemodel.inside) = abs(mean(mom(:,sel(1):sel(2)),2));
  figure;ft_plot_mesh(sourcemodel, 'vertexcolor', M);
  h = light('position', [0 -1 0]);lighting gouraud; material dull; drawnow;
  
  [~,ix] = max(M);
  
  ft_hastoolbox('cellfunction', 1); % this contains a bunch of functions that operate on cell-arrays
  data_vc = keepfields(dataw_meg, {'time' 'fsample' 'trialinfo'});
  assert(isequal(leadfield_meg.label, dataw_meg.label));
  data_vc.trial = source.avg.filter{ix}*dataw_meg.trial;
  data_vc.label = {'virtualchannel'};
  
  % split the 3 conditions
  cfg        = [];
  cfg.trials = find(data_vc.trialinfo(:,1)==1);
  cfg.preproc.demean = 'yes';
  cfg.preproc.baselinewindow = [-0.1 0];
  avg_famous = ft_timelockanalysis(cfg, data_vc);
  cfg.trials = find(data_vc.trialinfo(:,1)==2);
  avg_unfamiliar = ft_timelockanalysis(cfg, data_vc);
  
  cfg.trials = find(data_vc.trialinfo(:,1)==3);
  avg_scrambled = ft_timelockanalysis(cfg, data_vc);
  
  cfg.trials = find(data_vc.trialinfo(:,1)==1 | data_vc.trialinfo(:,1)==2);
  avg_faces  = ft_timelockanalysis(cfg, data_vc);
  
  figure;plot(avg_famous.time, [eye(3);-.5 -.5 1]*[avg_famous.avg;avg_unfamiliar.avg;avg_scrambled.avg]);
  legend({'famous';'unfamiliar';'scrambled';'faces vs. scrambled'});
  
  
  filename = fullfile(subj.outputpath, 'sourceanalysis', sprintf('%s_virtualchannel', subj.name));
  save(filename, 'avg_famous', 'avg_unfamiliar', 'avg_scrambled', 'avg_faces', 'ix', 'data_vc');
  
end

if doparcellate
  
  load atlas_subparc374_8k.mat
  
  % in principle, the function ft_sourceparcellate can be used for
  % parcellating the source level data. Here, the intention is to create
  % the parcellation based on an svd of the parcel-wise data covariance, as
  % represented in the spatially filtered sensor covariance. this requires
  % the sensor covariance to be sandwiched between the concatenated spatial
  % filters for the given parcels. This is currently not supported by
  % ft_sourceparcellate, so it will be done by hand here
  F = zeros(374,numel(dataw_meg.label));
  for k = 1:numel(atlas.parcellationlabel)
    sel = atlas.parcellation==k;
    f   = cat(1, source.avg.filter{sel});
    C   = f*tlckw.cov*f';
    [u,s,v] = svd(C);
    F(k,:)  = u(:,1)'*f;
  end
  data_parc = keepfields(dataw_meg, {'time' 'fsample' 'trialinfo'});
  assert(isequal(leadfield_meg.label, dataw_meg.label));
  data_parc.trial = F*dataw_meg.trial;
  data_parc.label = atlas.parcellationlabel;
  
  cfg        = [];
  cfg.trials = find(data_parc.trialinfo(:,1)==1);
  cfg.preproc.demean = 'yes';
  cfg.preproc.baselinewindow = [-0.1 0];
  avg_famous = ft_timelockanalysis(cfg, data_parc);
  cfg.trials = find(data_parc.trialinfo(:,1)==2);
  avg_unfamiliar = ft_timelockanalysis(cfg, data_parc);
  
  cfg.trials = find(data_parc.trialinfo(:,1)==3);
  avg_scrambled = ft_timelockanalysis(cfg, data_parc);
  
  cfg.trials = find(data_parc.trialinfo(:,1)==1 | data_parc.trialinfo(:,1)==2);
  avg_faces  = ft_timelockanalysis(cfg, data_parc);
  
  filename = fullfile(subj.outputpath, 'sourceanalysis', sprintf('%s_source_parc', subj.name));
  save(filename, 'avg_famous', 'avg_unfamiliar', 'avg_scrambled', 'avg_faces');
  
end
