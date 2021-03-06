function cg_vbm_run_oldcatch(job,estwrite,tpm,subj)
% ______________________________________________________________________
% This function contains an old matlab try-catch block. MATLAB2007a does 
% not support an error variable and throw an error even it is printed as
% simple warning. 
% The problem was now that using the lasterror function does not work, 
% because the last error was maybe catch in another try-catch block, and
% was not responsible for the crash.
% The new try-catch block has to be in a separate file to avoid an error.
%
% See also cg_vbm_run_newcatch.
% ______________________________________________________________________
% $Revision$  $Date$
    
  if cg_vbm_get_defaults('extopts.ignoreErrors')
    try
      cg_vbm_run_job(job,estwrite,tpm,subj); %#ok<NASGU>
    catch
      vbmerr = lasterror;  %#ok<LERR>,
      vbm_io_cprintf('err',sprintf('\n%s\nVBM Preprocessing error: %s: %s \n%s\n%s\n%s\n', ...
        repmat('-',1,72),vbmerr.identifier,...
        spm_str_manip(job.channel(1).vols{subj},'a60'),...
        repmat('-',1,72),vbmerr.message,repmat('-',1,72)));  
      %vbm_io_cprintf('err',sprintf('\n%s\nVBM Preprocessing error: %s\n%s\n%s\n%s\n', ...
      %  repmat('-',1,72),...
      %  spm_str_manip(job.channel(1).vols{subj},'a70'),...
      %  repmat('-',1,72)));  

      % write error report
      vbmerrtxt = cell(numel(vbmerr.stack),1);
      for si=1:numel(vbmerr.stack)
        vbm_io_cprintf('err',sprintf('%5d - %s\n',vbmerr.stack(si).line,vbmerr.stack(si).name));  
        vbmerrtxt{si} = sprintf('%5d - %s\n',vbmerr.stack(si).line,vbmerr.stack(si).name); 
      end
      vbm_io_cprintf('err',sprintf('%s\n',repmat('-',1,72)));  

      % delete template files 
      [pth,nam,ext] = spm_fileparts(job.channel(1).vols{subj}); 
      % delete noise corrected image
      if exist(fullfile(pth,['n' nam ext]),'file')
        try %#ok<TRYNC>
          delete(fullfile(pth,['n' nam ext]));
        end
      end
      
      % save vbm xml file
      vbmerrstruct = struct();
      for si=1:numel(vbmerr.stack)
        vbmerrstruct(si).line = vbmerr.stack(si).line;
        vbmerrstruct(si).name = vbmerr.stack(si).name;  
        vbmerrstruct(si).file = vbmerr.stack(si).file;  
      end
      vbm_tst_qa('vbm12err',struct('write_csv',0,'write_xml',1,'vbmerrtxt',vbmerrtxt,'vbmerr',vbmerrstruct,'job',job));
      
      % delete noise corrected image
      if exist(fullfile(pth,['n' nam(2:end) ext]),'file')
        try %#ok<TRYNC>
          delete(fullfile(pth,['n' nam(2:end) ext]));
        end
      end
    end
  else
    cg_vbm_run_job(job,estwrite,tpm,subj);
  end
end