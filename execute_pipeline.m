function execute_pipeline(pipelinename, subj, varargin)

% EXECUTE_PIPELINE serves the purpose to make a script executable by qsub.
% supply it with the name of the script that has to be run, and the
% subj-structure. the subj variable is assumed to be the only required free parameter in
% the script.
%
% example use in combination with qsubfeval:
%
% subj = datainfo_subject(1);
% pipelinename = 'pipeline_raw2erp';
%
% timreq = 60*60;
% memreq = 4*1024^3
% qsubfeval('execute_pipeline', pipelinename, subj, 'memreq', memreq, 'timreq', timreq);

if numel(varargin)>0
  for k = 1:numel(varargin)
    eval([varargin{k}{1},'=varargin{k}{2}']);
  end
end
eval(pipelinename);
