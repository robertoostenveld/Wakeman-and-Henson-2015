doforward  = true;
dolcmv     = true;
dovirtchan = false;
doparcellate = true;
percondition = true;
if doforward
  
  % load the sensor-level data
  filename = fullfile(subj.outputpath, 'raw2erp', subj.name, sprintf('%s_data', subj.name));
  load(filename, 'data');
  
  % select the electrophysiological channels
  cfg         = [];
  cfg.channel = {'MEG'};
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
  
  % let's have a look at the combined covariance matrix
  C = baseline_avg.cov([find(selmag);find(selgrad)],[find(selmag);find(selgrad)]);
  figure;imagesc(C);hold on;plot(102.5.*[1 1],[0 306],'w','linewidth',2);plot([0 306],102.5.*[1 1],'w','linewidth',2);
  
  % an SVD gives an indication of the numerical properties of a matrix
  [u,s,v] = svd(baseline_avg.cov);
  figure;plot(log10(diag(s)),'o');
  
  % the beamformer requires the mathematical inverse of the covariance
  % matrix, how does this look?:
  figure;imagesc(inv(C)); %-> this throws an error
  figure;imagesc(pinv(C));
  
  [u,s_mag,v]  = svd(baseline_avg.cov(selmag,  selmag));
  [u,s_grad,v] = svd(baseline_avg.cov(selgrad, selgrad));
  hold on
  plot(log10(diag(s_grad)),'o');
  plot(log10(diag(s_mag)),'o');
  
  d_mag = -diff(log10(diag(s_mag))); d_mag = d_mag./std(d_mag);
  kappa_mag = find(d_mag>4,1,'first');
  d_grad = -diff(log10(diag(s_grad))); d_grad = d_grad./std(d_grad);
  kappa_grad = find(d_grad>4,1,'first');
    
  cfg            = [];
  cfg.channel    = 'meg';
  cfg.kappa      = min(kappa_mag,kappa_grad);
  dataw_meg      = ft_denoise_prewhiten(cfg, data, baseline_avg);
  
  % select the 'baseline'
  cfg         = [];
  cfg.latency = [-0.2 0];
  baselinew   = ft_selectdata(cfg, dataw_meg);
  
  % compute the baseline covariance
  cfg            = [];
  cfg.covariance = 'yes';
  baselinew_avg   = ft_timelockanalysis(cfg, baselinew);
  
  selmag  = ft_chantype(baselinew_avg.label, 'megmag');
  selgrad = ft_chantype(baselinew_avg.label, 'megplanar');
  
  Cw = baselinew_avg.cov([find(selmag);find(selgrad)],[find(selmag);find(selgrad)]);
  figure;imagesc(Cw); hold on;plot(102.5.*[1 1],[0 306],'w','linewidth',2);plot([0 306],102.5.*[1 1],'w','linewidth',2);
 
  % compute the svd on the whitened covariance matrix
  [u,s,v] = svd(baselinew_avg.cov);
  figure;plot(log10(diag(s)),'o');
  
  
%   % do a quick and dirty artifact rejection
%   cfg = [];
%   cfg.layout = 'neuromag306mag_helmet.mat';
%   layout     = ft_prepare_layout(cfg);
%   
%   cfg = [];
%   cfg.method = 'summary';
%   cfg.layout = layout;
%   dataw_meg  = ft_rejectvisual(cfg, dataw_meg);
%   
  cfg                = [];
  cfg.preproc.baselinewindow = [-0.2 0];
  cfg.preproc.demean = 'yes';
  cfg.covariance     = 'yes';
  tlckw              = ft_timelockanalysis(cfg, dataw_meg);
  
  
  % obtain the necessary ingredients for obtaining a forward model
  load(fullfile(subj.outputpath, 'anatomy', subj.name, sprintf('%s_headmodel', subj.name)));
  load(fullfile(subj.outputpath, 'anatomy', subj.name, sprintf('%s_sourcemodel', subj.name)));
  headmodel   = ft_convert_units(headmodel,   tlckw.grad.unit);
  sourcemodel = ft_convert_units(sourcemodel, tlckw.grad.unit);
  sourcemodel.inside = sourcemodel.atlasroi>0;
  
  % compute the forward model for the whitened data
  cfg             = [];
  cfg.channel     = tlckw.label;
  cfg.grad        = tlckw.grad;
  cfg.sourcemodel = sourcemodel;
  cfg.headmodel   = headmodel;
  cfg.method      = 'singleshell';
  cfg.singleshell.batchsize = 1000;
  leadfield_meg   = ft_prepare_leadfield(cfg); % NOTE: input of the whitened data ensures the correct sensor definition to be used
end

if dolcmv
  
  if ~exist('leadfield_meg', 'var')
    error('the forward computation step needs to be performed in order to do inverse modelling');
  end
  
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
  cfg.headmodel   = headmodel;
  cfg.sourcemodel = leadfield_meg;
  source          = ft_sourceanalysis(cfg, tlckw);
 
  filename = fullfile(subj.outputpath, 'sourceanalysis', subj.name, sprintf('%s_source_lcmv', subj.name));
  save(filename, 'source', 'tlckw');
  
  
  wb_dir = fullfile(subj.outputpath, 'anatomy', subj.name, 'freesurfer', subj.name, 'workbench');
  filename = fullfile(wb_dir, sprintf('%s.L.inflated.8k_fs_LR.surf.gii', subj.name));
  inflated = ft_read_headshape({filename strrep(filename, '.L.', '.R.')});
  inflated = ft_determine_units(inflated);
  inflated.coordsys = 'neuromag';
  
  cfg           = [];
  cfg.clim      = [-2.5 2.5];
  cfg.colormap  = 'parula';
  cfg.parameter = 'mom';
  
  % replace the original dipole positions with those of the inflated
  % surface
  source.pos = inflated.pos;
  figure;ft_sourceplot_interactive(cfg, source);
  
end

if percondition
  
  if ~exist('source', 'var')
    error('this step requires the source variable to exist');
  end
  
  cfg                = [];
  cfg.preproc.baselinewindow = [-0.2 0];
  cfg.preproc.demean = 'yes';
  cfg.covariance     = 'yes';
  
  cfg.trials = find(dataw_meg.trialinfo(:,1)==1);
  tlckw_famous = ft_timelockanalysis(cfg, dataw_meg);
  
  cfg.trials = find(dataw_meg.trialinfo(:,1)==2);
  tlckw_unfamiliar = ft_timelockanalysis(cfg, dataw_meg);
  
  cfg.trials = find(dataw_meg.trialinfo(:,1)==3);
  tlckw_scrambled = ft_timelockanalysis(cfg, dataw_meg);
 
  cfg                 = [];
  cfg.method          = 'lcmv';
  cfg.lcmv.kappa      = kappa;
  cfg.lcmv.keepfilter = 'yes';
  cfg.lcmv.fixedori   = 'yes';
  cfg.lcmv.weightnorm = 'unitnoisegain';
  cfg.headmodel   = headmodel;
  cfg.sourcemodel = leadfield_meg;
  cfg.sourcemodel.filter = source.avg.filter;
  cfg.sourcemodel.filterdimord = source.avg.filterdimord;
  source_famous_orig     = ft_sourceanalysis(cfg, tlckw_famous);
  source_unfamiliar_orig = ft_sourceanalysis(cfg, tlckw_unfamiliar);
  source_scrambled_orig  = ft_sourceanalysis(cfg, tlckw_scrambled);
  
  cfg = [];
  cfg.operation = 'abs';
  cfg.parameter = 'mom';
  source_famous = ft_math(cfg, source_famous_orig);
  source_unfamiliar = ft_math(cfg, source_unfamiliar_orig);
  source_scrambled  = ft_math(cfg, source_scrambled_orig);
  
  cfg           = [];
  cfg.parameter = 'mom';
  figure;ft_sourceplot_interactive(cfg, source_famous, source_unfamiliar, source_scrambled);
  
  cfg = [];
  cfg.operation = 'subtract';
  cfg.parameter = 'mom';
  source_diff   = ft_math(cfg, source_famous, source_scrambled);
  
  cfg           = [];
  cfg.parameter = 'mom';
  cfg.has_diff  = true;
  figure;ft_sourceplot_interactive(cfg, source_famous, source_scrambled, source_diff);
  
end


if dovirtchan
   
  if ~exist('source', 'var') || ~exist('dataw_meg', 'var')
    error('the forward modelling and lcmv steps need to be performed in order to do inverse modelling');
  end
 
  mom = cat(1,source.avg.mom{:});
  
  sel = nearest(source.time,[0.16 0.17]);
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
  
%   % in principle, the function ft_sourceparcellate can be used for
%   % parcellating the source level data. Here, the intention is to create
%   % the parcellation based on an svd of the parcel-wise data covariance, as
%   % represented in the spatially filtered sensor covariance. this requires
%   % the sensor covariance to be sandwiched between the concatenated spatial
%   % filters for the given parcels. This is currently not supported by
%   % ft_sourceparcellate, so it will be done by hand here
%   F = zeros(374,numel(dataw_meg.label));
%   for k = 1:numel(atlas.parcellationlabel)
%     sel = atlas.parcellation==k;
%     f   = cat(1, source.avg.filter{sel});
%     C   = f*tlckw.cov*f';
%     [u,s,v] = svd(C);
%     F(k,:)  = u(:,1)'*f;
%   end
%   data_parc = keepfields(dataw_meg, {'time' 'fsample' 'trialinfo'});
%   assert(isequal(leadfield_meg.label, dataw_meg.label));
%   data_parc.trial = F*dataw_meg.trial;
%   data_parc.label = atlas.parcellationlabel;
%   
%   cfg        = [];
%   cfg.trials = find(data_parc.trialinfo(:,1)==1);
%   cfg.preproc.demean = 'yes';
%   cfg.preproc.baselinewindow = [-0.1 0];
%   avg_famous = ft_timelockanalysis(cfg, data_parc);
%   cfg.trials = find(data_parc.trialinfo(:,1)==2);
%   avg_unfamiliar = ft_timelockanalysis(cfg, data_parc);
%   
%   cfg.trials = find(data_parc.trialinfo(:,1)==3);
%   avg_scrambled = ft_timelockanalysis(cfg, data_parc);
%   
%   cfg.trials = find(data_parc.trialinfo(:,1)==1 | data_parc.trialinfo(:,1)==2);
%   avg_faces  = ft_timelockanalysis(cfg, data_parc);
%   

  cfg = [];
  cfg.method = 'eig';
  cfg.parameter = 'mom';
  atlas.pos = source_famous.pos;
  avg_famous     = ft_sourceparcellate(cfg, source_famous,     atlas);
  avg_unfamiliar = ft_sourceparcellate(cfg, source_unfamiliar, atlas);
  avg_scrambled  = ft_sourceparcellate(cfg, source_scrambled,  atlas);
  
  cfg = [];
  cfg.operation = 'abs';
  cfg.parameter = 'mom';
  avg_famous     = ft_math(cfg, avg_famous); 
  avg_unfamiliar = ft_math(cfg, avg_unfamiliar); 
  avg_scrambled  = ft_math(cfg, avg_scrambled); 
  
  avg_famous.cfg.previous.previous{1}.previous.callinfo.usercfg = removefields( ...
    avg_famous.cfg.previous.previous{1}.previous.callinfo.usercfg, 'sourcemodel' );
  avg_unfamiliar.cfg.previous.previous{1}.previous.callinfo.usercfg = removefields( ...
    avg_unfamiliar.cfg.previous.previous{1}.previous.callinfo.usercfg, 'sourcemodel' );
  avg_scrambled.cfg.previous.previous{1}.previous.callinfo.usercfg = removefields( ...
    avg_scrambled.cfg.previous.previous{1}.previous.callinfo.usercfg, 'sourcemodel' );
  
  
  filename = fullfile(subj.outputpath, 'sourceanalysis', subj.name, sprintf('%s_source_parc', subj.name));
  save(filename, 'avg_famous', 'avg_unfamiliar', 'avg_scrambled');
  
end
