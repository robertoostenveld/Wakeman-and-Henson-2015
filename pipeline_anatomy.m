% this script does the necessary processing of the anatomical images, that
% is required for forward and inverse modeling.
% 1) coregistration of the anatomical image with the MEG coordinate system
% 2) creation of a volume conduction model of the head
% 3) creation of a cortical sheet based sourcemodel, using freesurfer

docoregistration = false;
doheadmodel      = false;
dofreesurfer     = false;
dopostfreesurfer = false;
dosourcemodel2d  = true;
makefigure       = false;

if docoregistration
  file_id = fopen(subj.fidfile);
  line = fgetl(file_id);
  LPA = [];
  RPA = [];
  NAS = [];
  while ~isequal(line, -1)
    if contains(line, 'LPA')
      tok = split(line, '[');
      tok = split(tok{2}, ']');
      vals = split(tok{1}, ',');
      LPA  = str2double(vals');
    end
    if contains(line, 'RPA')
      tok = split(line, '[');
      tok = split(tok{2}, ']');
      vals = split(tok{1}, ',');
      RPA  = str2double(vals');
    end
    if contains(line, 'Nasion')
      tok = split(line, '[');
      tok = split(tok{2}, ']');
      vals = split(tok{1}, ',');
      NAS  = str2double(vals');
    end
    line = fgetl(file_id);
  end
  fclose(file_id);
  
  mri = ft_read_mri(subj.mrifile);
  
  cfg              = [];
  cfg.method       = 'fiducial';
  cfg.fiducial.nas = NAS; % this information has been obtained from the .json associated with the anatomical image
  cfg.fiducial.lpa = LPA;
  cfg.fiducial.rpa = RPA;
  cfg.coordsys     = 'neuromag';
  mri              = ft_volumerealign(cfg, mri);
  
  mkdir(fullfile(subj.outputpath, 'anatomy', 'freesurfer'));
  
  cfg              = [];
  cfg.filename     = fullfile(subj.outputpath, 'anatomy', 'freesurfer', subj.name);
  cfg.filetype     = 'mgz';
  cfg.parameter    = 'anatomy';
  ft_volumewrite(cfg, mri);
 
end

if doheadmodel
  
  thr = 0.5;
  
  % segment the coregistered mri
  cfg                = [];
  cfg.output         = 'brain';
  cfg.brainthreshold = thr;
  seg = ft_volumesegment(cfg, mri);
  
  % create the mesh
  cfg        = [];
  cfg.method = 'singleshell';
  headmodel  = ft_prepare_headmodel(cfg, seg);
  save(fullfile(subj.outputpath, 'anatomy', sprintf('%s_headmodel', subj.name)), 'headmodel');
    
end

if dofreesurfer

  [dum, ft_path] = ft_version; 
  scriptname = fullfile(ft_path,'bin','ft_freesurferscript.sh');
  subj_dir   = fullfile(subj.outputpath, 'anatomy', 'freesurfer');
  cmd_str    = sprintf('echo "%s %s %s" | qsub -l walltime=20:00:00,mem=8gb -N sub-%02d', scriptname, subj_dir, subj.name, subj.id);
  system(cmd_str);

end

if dopostfreesurfer
  
  [dum, ft_path] = ft_version; 
  scriptname = fullfile(ft_path,'bin','ft_postfreesurferscript.sh');
  subj_dir   = fullfile(subj.outputpath, 'anatomy', 'freesurfer');
  templ_dir  = '/home/language/jansch/projects/Pipelines/global/templates/standard_mesh_atlases';%fullfile(ft_path,'template','sourcemodel');
  cmd_str    = sprintf('echo "%s %s %s %s" | qsub -l walltime=20:00:00,mem=8gb -N sub-%02d', scriptname, subj_dir, subj.name, templ_dir, subj.id);
  
  %cmd_str    = sprintf('module load hcp-workbench; source %s %s %s %s', scriptname, subj_dir, subj_name, templ_dir);
  system(cmd_str);

end

if dosourcemodel2d

  wb_dir = fullfile(subj.outputpath, 'anatomy', 'freesurfer', subj.name, 'workbench');
  filename = fullfile(wb_dir, sprintf('%s.L.midthickness.8k_fs_LR.surf.gii', subj.name));
  sourcemodel = ft_read_headshape({filename strrep(filename, '.L.', '.R.')});
  sourcemodel = ft_determine_units(sourcemodel);
  sourcemodel.coordsys = 'neuromag';
  save(fullfile(subj.outputpath, 'anatomy', sprintf('%s_sourcemodel', subj.name)), 'sourcemodel');
  
end

if makefigure
  
  subj = datainfo_subject(15);
  hdr  = ft_read_header(subj.megfile{1}, 'coilaccuracy', 0);
  grad = ft_convert_units(hdr.grad, 'mm');
  
  load(fullfile(subj.outputpath, 'anatomy', sprintf('%s_headmodel', subj.name)));
  load(fullfile(subj.outputpath, 'anatomy', sprintf('%s_sourcemodel', subj.name)));
  headmodel   = ft_convert_units(headmodel,   'mm');
  sourcemodel = ft_convert_units(sourcemodel, 'mm');
  
  figure;hold on;
  ft_plot_mesh(sourcemodel, 'facecolor', [0.8 0.2 0.2]);
  ft_plot_headmodel(headmodel, 'edgecolor', 'none', 'facealpha', 0.3);
  ft_plot_sens(grad);
  h = light; lighting gouraud; material dull;

  
  % NOTE: sub-08 has a suboptimal sourcemodel, which is the result of a
  % failure of the default automatic freesurfer pipeline. This needs to be
  % fixed by manually cleaning the wm-segmentation, and re-run autorecon2/3
  % sub-06 and sub-07 also have some vertices extending from the headmodel
end