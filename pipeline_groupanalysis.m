% this script does group analysis on the parcellated source reconstructed time courses

%%

clear subj
iSub = 0;
for k = [1:8 10:16]
  iSub = iSub+1;
  subj(iSub) = datainfo_subject(k);
end

% all groupanalysis data goes into the same directory
outputpath = subj(1).outputpath;

%%

for k = 1:numel(subj)
  filename = fullfile(subj(k).outputpath, 'sourceanalysis', subj(k).name, sprintf('%s_source_parc', subj(k).name));
  
  % load the data from the file, organize each condition in a cell-array
  dum = load(filename, 'avg_famous', 'avg_unfamiliar', 'avg_scrambled');
  
  dum.avg_famous.avg = dum.avg_famous.mom;
  dum.avg_famous.dimord = dum.avg_famous.momdimord;
  dum.avg_famous = removefields(dum.avg_famous, {'mom', 'momdimord'});
  dum.avg_unfamiliar.avg = dum.avg_unfamiliar.mom;
  dum.avg_unfamiliar.dimord = dum.avg_unfamiliar.momdimord;
  dum.avg_unfamiliar = removefields(dum.avg_unfamiliar, {'mom', 'momdimord'});
  dum.avg_scrambled.avg = dum.avg_scrambled.mom;
  dum.avg_scrambled.dimord = dum.avg_scrambled.momdimord;
  dum.avg_scrambled = removefields(dum.avg_scrambled, {'mom', 'momdimord'});
  
  avg_famous{k} = dum.avg_famous;
  avg_unfamiliar{k} = dum.avg_unfamiliar;
  avg_scrambled{k} = dum.avg_scrambled;
  clear dum
end

filename = fullfile(outputpath, 'groupanalysis', 'avg_famous.mat');
% save(filename, 'avg_famous');

filename = fullfile(outputpath, 'groupanalysis', 'avg_unfamiliar.mat');
% save(filename, 'avg_unfamiliar');

filename = fullfile(outputpath, 'groupanalysis', 'avg_scrambled.mat');
% save(filename, 'avg_scrambled');

%%

% calculate grand average for each condition
cfg = [];
cfg.channel = 'all';
cfg.latency = 'all';
cfg.parameter = 'avg';
grandavg_famous = ft_timelockgrandaverage(cfg, avg_famous{:});
grandavg_unfamiliar = ft_timelockgrandaverage(cfg, avg_unfamiliar{:});
grandavg_scrambled = ft_timelockgrandaverage(cfg, avg_scrambled{:});
% "{:}" means to use data from all elements of the cell-array

filename = fullfile(outputpath, 'groupanalysis', 'grandavg_famous.mat');
% save(filename, 'grandavg_famous');
load(filename, 'grandavg_famous');

filename = fullfile(outputpath, 'groupanalysis', 'grandavg_unfamiliar.mat');
% save(filename, 'grandavg_unfamiliar');
load(filename, 'grandavg_unfamiliar');

filename = fullfile(outputpath, 'groupanalysis', 'grandavg_scrambled.mat');
% save(filename, 'grandavg_scrambled');
load(filename, 'grandavg_scrambled');

%%

% virtual channels are not arranged acoording to a known layout
cfg = [];
cfg.rows = 20;
cfg.columns = 20;
cfg.layout = 'ordered';
layout = ft_prepare_layout(cfg, grandavg_famous);
ft_plot_layout(layout, 'interpreter', 'none', 'fontsize', 8)

%%

cfg = [];
cfg.layout = layout;
ft_multiplotER(cfg, grandavg_famous, grandavg_unfamiliar, grandavg_scrambled);
% channel number 291 has a clear ERP, which is different between faces and scrambled

% print -dpng figure1.png

%%

cfg = [];
cfg.channel = 291;
ft_singleplotER(cfg, grandavg_famous, grandavg_unfamiliar, grandavg_scrambled);

% print -dpng figure2.png

%%

chan = 291;

brainordinate = avg_scrambled{1}.brainordinate;
color = ones(length(brainordinate.parcellation), 3) * 0.9; % light grey
color(brainordinate.parcellation==chan, 1) = 1; % red
color(brainordinate.parcellation==chan, 2) = 0;
color(brainordinate.parcellation==chan, 3) = 0;
ft_plot_mesh(brainordinate, 'vertexcolor', color)
view(0, -45)
camlight

% print -dpng figure3.png

%%

chan = 291;
time = [0.150 0.200];
% Scaling of the vertical axis for the plots below
ymax = 10;
figure;
for iSub = 1:numel(subj)
  subplot(3, 5, iSub)
  % use the rectangle to indicate the time range used later
  rectangle('Position', [time(1) 0 (time(2)-time(1)) ymax], 'FaceColor', [1 1 1]*0.9);
  hold on;
  % plot the lines in front of the rectangle
  plot(avg_famous{iSub}.time, avg_famous{iSub}.avg(chan, :));
  plot(avg_scrambled{iSub}.time, avg_scrambled{iSub}.avg(chan, :), 'r');
  title(strcat('subject ', num2str(iSub)))
  % ylim([0 ymax])
  xlim([-0.5 1.2])
end
legend({'famous', 'scrambled'})

% print -dpng figure4.png

%%

% find the data points for the effect of interest in the grand average
chan = 291;
time = [0.150 0.200];
timesel = find(grandavg_famous.time >= time(1) & grandavg_famous.time <= time(2));

% select the individual subject data and calculate the mean
for iSub = 1:numel(subj)
  values_famous(iSub) = mean(avg_famous{iSub}.avg(chan, timesel));
  values_scrambled(iSub) = mean(avg_scrambled{iSub}.avg(chan, timesel));
end

% plot to see the effect in each subject
M = [values_scrambled', values_famous'];
figure; plot(M', 'o-'); xlim([0.5 2.5])
legend({subj.name}, 'location', 'EastOutside');

% print -dpng figure5.png

%%

% dependent samples ttest
famous_minus_scrambled = values_famous - values_scrambled;
[h, p, ci, stats] = ttest(famous_minus_scrambled, 0, 0.05) % H0: mean = 0, alpha 0.05

%%

% define the parameters for the statistical comparison

cfg = [];
cfg.channel = 291;
cfg.latency = [0.150 0.200];
cfg.avgovertime = 'yes';
cfg.parameter = 'avg';
cfg.method = 'analytic';
cfg.statistic = 'ft_statfun_depsamplesT';
cfg.alpha = 0.05;
cfg.correctm = 'no';

Nsub = 15;
cfg.design(1, 1:2*Nsub) = [ones(1, Nsub) 2*ones(1, Nsub)];
cfg.design(2, 1:2*Nsub) = [1:Nsub 1:Nsub];
cfg.ivar = 1; % the 1st row in cfg.design contains the independent variable
cfg.uvar = 2; % the 2nd row in cfg.design contains the subject number

stat = ft_timelockstatistics(cfg, avg_famous{:}, avg_scrambled{:}); % don't forget the {:}

%%

time = [0.150 0.200];
timesel = find(grandavg_famous.time >= time(1) & grandavg_famous.time <= time(2));

clear h p

famous_minus_scrambled = zeros(1, 15);

% loop over channels
for iChan = 1:374
  for iSub = 1:15
    famous_minus_scrambled(iSub) = ...
      mean(avg_famous{iSub}.avg(iChan, timesel)) - ...
      mean(avg_scrambled{iSub}.avg(iChan, timesel));
  end
  
  [h(iChan), p(iChan)] = ttest(famous_minus_scrambled, 0, 0.05 ); % test each channel separately
end

%%

cfg = [];
cfg.operation = 'subtract';
cfg.parameter = 'avg';
grandavg_effect = ft_math(cfg, grandavg_famous, grandavg_scrambled);

% plot uncorrected "significant" channels
cfg = [];
cfg.layout = layout;
cfg.colorgroups = 1:374;
cfg.linecolor = ones(374, 3) * 0.5; % light grey
cfg.linecolor(find(h), 1) = 1;
cfg.linecolor(find(h), 2) = 0;
cfg.linecolor(find(h), 3) = 0;

cfg.comment = 'no';
figure; ft_multiplotER(cfg, grandavg_effect)
title('Parametric: significant without multiple comparison correction')

% print -dpng figure6.png

%%

% with Bonferroni correction for multiple comparisons
famous_minus_scrambled = zeros(1, 15);

for iChan = 1:374
  for iSub = 1:15
    famous_minus_scrambled(iSub) = ...
      mean(avg_famous{iSub}.avg(iChan, timesel)) - ...
      mean(avg_scrambled{iSub}.avg(iChan, timesel));
  end
  
  [h(iChan), p(iChan)] = ttest(famous_minus_scrambled, 0, 0.05/374); % test each channel separately
end

%%

cfg = [];
cfg.channel = 'all';
cfg.latency = [0.150 0.200];
cfg.avgovertime = 'yes';
cfg.parameter = 'avg';
cfg.method = 'analytic';
cfg.statistic = 'ft_statfun_depsamplesT';
cfg.alpha = 0.05;
cfg.correctm = 'bonferroni';

Nsub = 15;
cfg.design(1, 1:2*Nsub) = [ones(1, Nsub) 2*ones(1, Nsub)];
cfg.design(2, 1:2*Nsub) = [1:Nsub 1:Nsub];
cfg.ivar = 1; % the 1st row in cfg.design contains the independent variable
cfg.uvar = 2; % the 2nd row in cfg.design contains the subject number

stat_bonferroni = ft_timelockstatistics(cfg, avg_famous{:}, avg_scrambled{:});

filename = fullfile(outputpath, 'groupanalysis', 'stat_bonferroni.mat');
% save(filename, 'stat_bonferroni');

%%

cfg = [];
cfg.channel = 'all';
% cfg.latency = [0.150 0.200]; % see below
% cfg.avgovertime = 'yes'; % see below
cfg.parameter = 'avg';
cfg.method = 'montecarlo';
cfg.statistic = 'ft_statfun_depsamplesT';
cfg.alpha = 0.05;
cfg.correctm = 'no';
cfg.correcttail = 'prob';
cfg.numrandomization = 1000;

Nsub = 15;
cfg.design(1, 1:2*Nsub) = [ones(1, Nsub) 2*ones(1, Nsub)];
cfg.design(2, 1:2*Nsub) = [1:Nsub 1:Nsub];
cfg.ivar = 1; % the 1st row in cfg.design contains the independent variable
cfg.uvar = 2; % the 2nd row in cfg.design contains the subject number

stat_nonparametric = ft_timelockstatistics(cfg, avg_famous{:}, avg_scrambled{:});

filename = fullfile(outputpath, 'groupanalysis', 'stat_nonparametric.mat');
% save(filename, 'stat_nonparametric');

% make the plot
cfg = [];
cfg.layout = layout;
cfg.colorgroups = 1:374;
cfg.linecolor = ones(374, 3) * 0.5; % light grey
cfg.linecolor(find(stat_nonparametric.mask), 1) = 1; % red
cfg.linecolor(find(stat_nonparametric.mask), 2) = 0;
cfg.linecolor(find(stat_nonparametric.mask), 3) = 0;

cfg.comment = 'no';
figure; ft_multiplotER(cfg, grandavg_effect)
title('Nonparametric: significant without multiple comparison correction')

% print -dpng figure7.png

%%

cfg = [];
cfg.channel = 'all';
cfg.neighbours = []; % no channel neighbours, only time
cfg.parameter = 'avg';
cfg.method = 'montecarlo';
cfg.statistic = 'ft_statfun_depsamplesT';
cfg.alpha = 0.05;
cfg.correctm = 'cluster';
cfg.correcttail = 'prob';
cfg.numrandomization = 500;

Nsub = 15;
cfg.design(1, 1:2*Nsub) = [ones(1, Nsub) 2*ones(1, Nsub)];
cfg.design(2, 1:2*Nsub) = [1:Nsub 1:Nsub];
cfg.ivar = 1; % the 1st row in cfg.design contains the independent variable
cfg.uvar = 2; % the 2nd row in cfg.design contains the subject number

cfg.spmversion = 'spm12';
stat_cluster = ft_timelockstatistics(cfg, avg_famous{:}, avg_scrambled{:});

filename = fullfile(outputpath, 'groupanalysis', 'stat_cluster.mat');
% save(filename, 'stat_cluster');

%%

% make a plot
cfg = [];
cfg.layout = layout;
cfg.maskparameter = 'mask';
cfg.maskstyle = 'box';

grandavg_effect.mask = stat_cluster.mask;

figure; ft_multiplotER(cfg, grandavg_effect)
title('Nonparametric: significant after cluster-based correction')

% print -dpng figure8.png

%%

brainordinate = avg_scrambled{1}.brainordinate;
color = -log10(min(stat_cluster.prob, [], 2));
color = nan(size(brainordinate.pos,1),1);
for i=1:374
  color(brainordinate.parcellation==i) = min(stat_cluster.prob(i,:),[],2);
end

ft_plot_mesh(brainordinate, 'vertexcolor', color)
view(0,0.2)
colormap('hot')
colorbar
camlight

% print -dpng figure9.png
