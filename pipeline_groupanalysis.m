cnt = 0;
for k = [1:8 10:16]
  cnt = cnt+1;
  subj(cnt) = datainfo_subject(k);
end

for k = 1:numel(subj)
  filename = fullfile(subj(k).outputpath, 'sourceanalysis', sprintf('%s_source_parc', subj(k).name));
  S(k) = load(filename, 'avg_scrambled', 'avg_faces');

  cfg = [];
  cfg.operation = 'abs';
  cfg.parameter = 'avg';
  faces{k}      = ft_math(cfg, S(k).avg_faces);
  scrambled{k}  = ft_math(cfg, S(k).avg_scrambled);
end


nsubj = numel(subj);

cfg = [];
cfg.method = 'montecarlo';
cfg.statistic = 'depsamplesT';
cfg.design    = [1*ones(1,nsubj) 2*ones(1,nsubj); 1:nsubj 1:nsubj];
cfg.ivar      = 1;
cfg.uvar      = 2;
cfg.numrandomization = 100;
stat = ft_timelockstatistics(cfg, faces{:}, scrambled{:});
