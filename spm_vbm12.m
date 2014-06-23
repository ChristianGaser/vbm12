function spm_vbm
% VBM12 Toolbox wrapper to call vbm functions
%_______________________________________________________________________
% Christian Gaser
% $Id$

rev = '$Rev$';

SPMid = spm('FnBanner',mfilename,rev);
[Finter,Fgraph,CmdLine] = spm('FnUIsetup','VBM12');
spm_help('!Disp','vbm12.man','',Fgraph,'Voxel-based morphometry toolbox for SPM12');

fig = spm_figure('GetWin','Interactive');
h0  = uimenu(fig,...
	'Label',	'VBM12',...
	'Separator',	'on',...
	'Tag',		'VBM',...
	'HandleVisibility','on');
h1  = uimenu(h0,...
	'Label',	'Estimate and write',...
	'Separator',	'off',...
	'Tag',		'Estimate and write',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.estwrite'');',...
	'HandleVisibility','on');
h2  = uimenu(h0,...
	'Label',	'Write already estimated segmentations',...
	'Separator',	'off',...
	'Tag',		'Write segmentations',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.write'');',...
	'HandleVisibility','on');
if 0
h3  = uimenu(h0,...
	'Label',	'Process longitudinal data',...
	'Separator',	'off',...
	'Tag',		'Process longitudinal data',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.long'');',...
	'HandleVisibility','off');
end
h4  = uimenu(h0,...
	'Label',	'Check data quality',...
	'Separator',	'off',...
	'Tag',		'Check data quality',...
	'HandleVisibility','on');
h41  = uimenu(h4,...
	'Label',	'Display one slice for all images',...
	'Separator',	'off',...
	'Tag',		'Display one slice for all images',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.showslice'');',...
	'HandleVisibility','on');
h42  = uimenu(h4,...
	'Label',	'Check sample homogeneity using sample correlation',...
	'Separator',	'off',...
	'Tag',		'Check sample homogeneity using sample correlation',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.check_cov'');',...
	'HandleVisibility','on');
h43  = uimenu(h4,...
	'Label',	'Check sample image quality',...
	'Separator',	'off',...
	'Tag',		'Check sample image quality',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.check_qa'');',...
	'HandleVisibility','on');
h5  = uimenu(h0,...
	'Label',	'Data presentation',...
	'Separator',	'off',...
	'Tag',		'Data presentation',...
	'HandleVisibility','on');
h51  = uimenu(h5,...
	'Label',	'Calculate raw volumes for GM/WM/CSF',...
	'Separator',	'off',...
	'Tag',		'VBM Calculate raw volumes for GM/WM/CSF',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.calcvol'');',...
	'HandleVisibility','on');
h52  = uimenu(h5,...
	'Label',	'Threshold and transform spmT-maps',...
	'Separator',	'off',...
	'Tag',		'Threshold and transform spmT-maps',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.T2x'');',...
	'HandleVisibility','on');
h53  = uimenu(h5,...
	'Label',	'Threshold and transform spmF-maps',...
	'Separator',	'off',...
	'Tag',		'Threshold and transform spmF-maps',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.F2x'');',...
	'HandleVisibility','on');
h54  = uimenu(h5,...
	'Label',	'Slice overlay',...
	'Separator',	'off',...
	'Tag',		'Slice overlay',...
	'CallBack','cg_slice_overlay;',...
	'HandleVisibility','on');
h6  = uimenu(h0,...
	'Label',	'Extended tools',...
	'Separator',	'off',...
	'Tag',		'Extended tools',...
	'HandleVisibility','on');
h61  = uimenu(h6,...
	'Label',	'Spatial adaptive non local means denoising filter',...
	'Separator',	'off',...
	'Tag',		'SANLM filter',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.sanlm'');',...
	'HandleVisibility','on');
h62  = uimenu(h6,...
	'Label',	'Intra-subject bias correction',...
	'Separator',	'off',...
	'Tag',		'Intra-subject bias correction',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.bias'');',...
	'HandleVisibility','on');
h63  = uimenu(h6,...
	'Label',	'Apply deformations (Many images)',...
	'Separator',	'off',...
	'Tag',		'Apply deformations (Many images)',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.defs'');',...
	'HandleVisibility','on');
h64  = uimenu(h6,...
	'Label',	'Apply deformations (Many subjects)',...
	'Separator',	'off',...
	'Tag',		'Apply deformations (Many subjects)',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.defs2'');',...
	'HandleVisibility','on');
h65  = uimenu(h6,...
	'Label',	'Set origin using center-of-mass',...
	'Separator',	'off',...
	'Tag',		'Set origin using center-of-mass',...
	'CallBack','cg_set_com;',...
	'HandleVisibility','on');
h7  = uimenu(h0,...
	'Label',	'Surface tools',...
	'Separator',	'off',...
	'Tag',		'Surface tools',...
	'HandleVisibility','on');
h71  = uimenu(h7,...
	'Label',	'Display surface',...
	'Separator',	'off',...
	'Tag',		'Display surface',...
	'CallBack', 'P=spm_select([1 12],''gifti'',''Select surface''); for i=1:size(P,1), h = spm_mesh_render(deblank(P(i,:))); set(h.figure,''MenuBar'',''none'',''Toolbar'',''none'',''Name'',spm_file(P(i,:),''short40''),''NumberTitle'',''off''); spm_mesh_render(''ColourMap'',h.axis,jet); spm_mesh_render(''ColourBar'',h.axis,''on'');end',...
	'HandleVisibility','on');
h72  = uimenu(h7,...
	'Label',	'Extract surface parameters',...
	'Separator',	'off',...
	'Tag',		'Extract surface parameters',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.surfextract'');',...
	'HandleVisibility','on');
h73  = uimenu(h7,...
	'Label',	'Resample and smooth surface parameters',...
	'Separator',	'off',...
	'Tag',		'Resample surface parameters to template space',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.surfresamp'');',...
	'HandleVisibility','on');
h74  = uimenu(h7,...
	'Label',	'Factorial design specification',...
	'Separator',	'off',...
	'Tag',		'Factorial design specification',...
	'CallBack','spm_jobman(''interactive'','''',''spm.stats.factorial_design'');',...
	'HandleVisibility','on');
h75  = uimenu(h7,...
	'Label',	'Estimate design',...
	'Separator',	'off',...
	'Tag',		'Estimate design',...
	'CallBack','vbm_spm;',...
	'HandleVisibility','on');
h76  = uimenu(h7,...
	'Label',	'Check sample homogeneity using sample correlation for surfaces',...
	'Separator',	'off',...
	'Tag',		'Check sample homogeneity using sample correlation for surfaces',...
	'CallBack','spm_jobman(''interactive'','''',''spm.tools.vbm.tools.check_mesh_cov'');',...
	'HandleVisibility','on');
h8  = uimenu(h0,...
	'Label',	'Print VBM debug information',...
	'Separator',	'on',...
	'Tag',		'Print debug information about versions and last error',...
	'CallBack','cg_vbm_debug;',...
	'HandleVisibility','on');
h9  = uimenu(h0,...
	'Label',	'VBM Tools website',...
	'Separator',	'off',...
	'Tag',		'Launch VBM Tools site',...
	'CallBack',['set(gcbf,''Pointer'',''Watch''),',...
			'web(''http://dbm.neuro.uni-jena.de/vbm'',''-browser'');',...
			'set(gcbf,''Pointer'',''Arrow'')'],...
	'HandleVisibility','on');
h10  = uimenu(h0,...
	'Label',	'Check for updates',...
	'Separator',	'off',...
	'Tag',		'Check for updates',...
	'CallBack','cg_vbm_update(1);',...
	'HandleVisibility','on');
h11  = uimenu(h0,...
	'Label',	'VBM12 Manual (PDF)',...
	'Separator',	'off',...
	'Tag',		'Open VBM12 Manual',...
	'CallBack','try,open(fullfile(spm(''dir''),''toolbox'',''vbm'',''VBM12-Manual.pdf''));end',...
	'HandleVisibility','on');


