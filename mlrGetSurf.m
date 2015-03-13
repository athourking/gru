function success = mlrGetSurf(project,password)
%   mlrGetSurf(project)
%
% GOAL:
% You should have already run mlrReconAll for your volumes. Now we're
% going to recover the actual data with the same rP settings. The data will
% get saved into the same directory structure that it was pulled out of
% NIMS on, in this subject's folder.
%
% project       Current project, e.g. 'retinotopy'

%% Build up our collection of files
possibleFiles = dir(fullfile('~/data/',project,'rP*.mat'));
doFiles = {};
for pi = 1:length(possibleFiles)
    cFile = possibleFiles(pi).name;
    if strcmp(input(sprintf('Get Surfaces for file: %s? y/n... ',cFile),'s'),'y')
        doFiles{end+1} = cFile;
    end
end

for fi = 1:length(doFiles)
    cFile = doFiles{fi};
    cFile = fullfile('~/data/',project,cFile);
    mlrGetSurfHelper(cFile);
end

%% Helpers

function success = mlrGetSurfHelper(file)
    
%% Load our file
load(file);

%% Check if we already ran this...
if checkForSurfFiles(reconParams.localDataPath)
    warning('It looks like you already ran mlrReconAll for this subject, this function will overwrite the files.');
end

%% Check if we are at Stanford in GRU lab (171.64.40.***)
ipPlus =  urlread('http://checkip.dyndns.org/');
if isempty(strfind(ipPlus,'171.64.40'))
    error('mlrReconAll and mlrGetSurf are only intended for use at Stanford, with the NIMS database!');
end

%% Check that reconParams has everything necessary
reconParams.conn = ssh2_config(reconParams.LXCServer,reconParams.user,password);

if ~isfield(reconParams,'conn') || ~isfield(reconParams,'LXCServer') || ~isfield(reconParams,'fstempPath') || ~isfield(reconParams,'localDataPath') || ~isfield(reconParams,'user')
    error('reconParams was not built correctly... cannot continue');
end

%% Connect to the LXC Server
try
    curDir = pwd;
    cd('~/proj/gru');
    addpath(genpath('~/proj/gru/ssh2_v2_m1_r6'));
    ssh2_conn = ssh2_config(reconParams.LXCServer,reconParams.user,password);
    cd(curDir);
catch e
    warning('Something went wrong with ssh2, are you sure you have the ssh2 folder on your path?');
    error(e);
end

%% Check if FreeSurfer is finished
ssh2_conn = ssh2_command(ssh2_conn,sprintf('ls %s',fullfile(reconParams.fstempPath,'surf')));
if isempty(ssh2_conn.command_result{1})
    warning('FreeSurfer didn''t finish running. Be patient!');
    success = 0;
    return
end
disp('FreeSurfer appears to have completed, checking for specific files.');

warning('Specific file checking is not implemented yet... if freesurfer didn''t completely finish you will be missing files');

%% SCP Files to /data/
localFullPath = reconParams.localDataPath;
scpCommand = sprintf('scp -r %s@%s:%s/* %s',reconParams.user,reconParams.LXCServer,reconParams.fstempPath,localFullPath);

disp(sprintf('\nPlease copy and paste the following into a terminal:\n\n%s',scpCommand));

%% Check that SCP succeeded
success = checkForSurfFiles(reconParams.localDataPath);
if ~success
    disp(sprintf('Use these commands to check whether FreeSurfer spit out all the correct files:\n\nssh -XY %s@%s\ncd %s/surf\nls\n\nYou should see these files (among others): lh.pial, lh.inflated, and lh.smoothwm',reconParams.user,reconParams.LXCServer,reconParams.fstempPath));
    error('File copy failed... Are you sure FreeSurfer finished successfully?');
end

%% Check if mrInit was run
warning('Not sure how to check for mrInit yet...');
mrInitFlag = 1;
%% Run mlrImportFreeSurfer
if mrInitFlag
    cDir = pwd;
    cd (reconParams.localDataPath)
    mlrImportFreeSurfer
    cd(cDir);
else
    warning('mlrImportFreeSurfer was not run, did you run mrInit?');
end

function success = checkForSurfFiles(dir)
dirs = {'surf','mri'};
files = {['lh.pial' 'rh.pial' 'lh.smoothwm' 'rh.smoothwm' 'lh.inflated' 'rh.inflated'], ['T1.mgz']};
for di = 1:length(dirs)
    cdir = dirs{di};
    for fi = 1:length(files)
        cfiles = files{fi};
        for fii = 1:length(cfiles)
            cfile = cfiles(fii);
            % check for file
            if ~isfile(fullfile(dir,cdir,cfile))
                success = 0;
                return
            end
        end
    end
end
success = 1;
return