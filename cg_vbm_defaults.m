function cg_vbm_defaults
% Sets the defaults for VBM
% FORMAT cg_vbm_defaults
%_______________________________________________________________________
%
% This file is intended to be customised for the site.
%
% Care must be taken when modifying this file
%_______________________________________________________________________
% $Id$

if exist('vbm','var'), clear vbm; end 
global vbm

% Important fields for the processing of animal data
%=======================================================================
% - vbm.opts.tpm 
% - vbm.extopts.darteltpm
% - vbm.extopts.vbm12atlas
% - vbm.extopts.brainmask
% - vbm.extopts.bb         > [-inf -inf -inf; inf inf inf] 
% - vbm.extopts.vox        > inf
% - vbm.opts.affreg        > subj
% - vbm.opts.biasreg       > 0.00001
% - vbm.opts.biasfwhm      > 40
% - vbm.opts.samp          > 2 mm
%=======================================================================


% Options for inital SPM12 segmentation that is used as starting point for VBM12
%=======================================================================
vbm.opts.tpm       = {fullfile(spm('dir'),'tpm','TPM.nii')};
vbm.opts.ngaus     = [3 3 2 3 4 2];           % Gaussians per class    - 3 GM and 3 WM classes for robustness
vbm.opts.affreg    = 'mni';                   % Affine regularisation  - '';'mni';'eastern';'subj';'none';'rigid';
vbm.opts.warpreg   = [0 0.001 0.5 0.05 0.2];  % Warping regularisation - see Dartel instructions
vbm.opts.biasreg   = 0.001;                   % Bias regularisation    - smaller values for stronger bias fields
vbm.opts.biasfwhm  = 60;                      % Bias FWHM              - lower values for stronger bias fields, but check for overfitting in subcortical GM (values <50 mm)
vbm.opts.samp      = 3;                       % Sampling distance      - smaller 'better', but slower - maybe useful for >= 7 Tesla 

                                              
% Writing options
%=======================================================================

% options:
%   native    0/1     (none/yes)
%   warped    0/1     (none/yes)
%   mod       0/1/2/3 (none/affine+nonlinear/nonlinear only/both)
%   dartel    0/1/2/3 (none/rigid/affine/both)

% save surface and thickness
vbm.output.surface     = 0;     % surface and thickness creation

% save ROI values
vbm.output.ROI         = 2;     % write csv-files with ROI data: 1 - subject space; 2 - normalized space; 3 - both (default 2)

% bias and noise corrected, (locally - if LAS>0) intensity normalized
vbm.output.bias.native = 0;
vbm.output.bias.warped = 1;
vbm.output.bias.dartel = 0;

% GM tissue maps
vbm.output.GM.native  = 0;
vbm.output.GM.warped  = 0;
vbm.output.GM.mod     = 2;
vbm.output.GM.dartel  = 0;

% WM tissue maps
vbm.output.WM.native  = 0;
vbm.output.WM.warped  = 0;
vbm.output.WM.mod     = 2;
vbm.output.WM.dartel  = 0;
 
% CSF tissue maps
vbm.output.CSF.native = 0;
vbm.output.CSF.warped = 0;
vbm.output.CSF.mod    = 0;
vbm.output.CSF.dartel = 0;

% WMH tissue maps (only for opt.extopts.WMHC==3) - in development
vbm.output.WMH.native  = 0;
vbm.output.WMH.warped  = 0;
vbm.output.WMH.mod     = 0;
vbm.output.WMH.dartel  = 0;

% label 
% background=0, CSF=1, GM=2, WM=3, WMH=4 (if opt.extropts.WMHC==3)
vbm.output.label.native = 0; 
vbm.output.label.warped = 0;
vbm.output.label.dartel = 0;

% jacobian determinant 0/1 (none/yes)
vbm.output.jacobian.warped = 0;

% deformations
% order is [forward inverse]
vbm.output.warps        = [0 0];


% Expert options
%=======================================================================

% skull-stripping options
vbm.extopts.gcutstr      = 0.5;   % Strengh of skull-stripping:               0 - no gcut; eps - softer and wider; 1 - harder and closer (default = 0.5)
vbm.extopts.cleanupstr   = 0.5;   % Strength of the cleanup process:          0 - no cleanup; eps - soft cleanup; 1 - strong cleanup (default = 0.5) 

% segmentation options
vbm.extopts.sanlm        = 3;     % use SANLM filter: 0 - no SANLM; 1 - SANLM; 3 - SANLM + ORNLM filter; 5 - only ORNLM filter for the final result
vbm.extopts.NCstr        = 0.5;   % Strength of the noise correction:         0 - no noise correction; eps - low correction; 1 - strong corrections (default = 0.5)
vbm.extopts.LASstr       = 0.5;   % Strength of the local adaption:           0 - no adaption; eps - lower adaption; 1 - strong adaption (default = 0.5)
vbm.extopts.BVCstr       = 0.5;   % Strength of the Blood Vessel Correction:  0 - no correction; eps - low correction; 1 - strong correction (default = 0.5)
vbm.extopts.WMHC         = 1;     % Correction of WM hyperintensities:        0 - no (VBM8); 1 - only for Dartel (default); 
                                  %                                           2 - also for segmentation (corred to WM like SPM); 3 - separate class
vbm.extopts.WMHCstr      = 0.5;   % Strength of WM hyperintensity correction: 0 - no correction; eps - for lower, 1 for stronger corrections (default = 0.5)
vbm.extopts.mrf          = 1;     % MRF weighting:                            0 - no MRF; 0 > mrf < 1 - manual setting; 1 - auto (default)
vbm.extopts.INV          = 1;     % Invert PD/T2 images for standard preprocessing:  0 - no processing, 1 - try intensity inversion (default), 2 - synthesize T1 image

% resolution options:
vbm.extopts.restype      = 'best';        % resolution handling: 'native','fixed','best'
vbm.extopts.resval       = [1.00 0.10];   % resolution value and its variance for the 'fixed' and 'best' restype

%{
native:
    Preprocessing with native resolution.
    In order to avoid interpolation artifacts in the Dartel output the lowest spatial resolution is always limited to the voxel size of the normalized images (default 1.5mm). 

    Examples:
      native resolution       internal resolution 
       0.95 0.95 1.05     >     0.95 0.95 1.05
       0.45 0.45 1.70     >     0.45 0.45 1.50 (if voxel size for normalized images is 1.50 mm)

best:
    Preprocessing with the best (minimal) voxel dimension of the native image.'
    The first parameters defines the lowest spatial resolution for every dimension, while the second is used to avoid tiny interpolations for almost correct resolutions.
    In order to avoid interpolation artifacts in the Dartel output the lowest spatial resolution is always limited to the voxel size of the normalized images (default 1.5mm). 

    Examples:
      Parameters    native resolution       internal resolution
      [1.00 0.10]    0.95 1.05 1.25     >     0.95 1.00 1.00
      [1.00 0.10]    0.45 0.45 1.50     >     0.45 0.45 1.00
      [0.75 0.10]    0.45 0.45 1.50     >     0.45 0.45 0.75  
      [0.75 0.10]    0.45 0.45 0.80     >     0.45 0.45 0.80  
      [0.00 0.10]    0.45 0.45 1.50     >     0.45 0.45 0.45  

fix:
    This options prefers an isotropic voxel size that is controled by the first parameters.  
    The second parameter is used to avoid tiny interpolations for almost correct resolutions. 
    In order to avoid interpolation artifacts in the Dartel output the lowest spatial resolution is always limited to the voxel size of the normalized images (default 1.5mm). 
    There is no upper limit, but we recommend to avoid unnecessary interpolation.

    Examples: 
      Parameters     native resolution       internal resolution
      [1.00 0.10]     0.45 0.45 1.70     >     1.00 1.00 1.00
      [1.00 0.10]     0.95 1.05 1.25     >     0.95 1.05 1.00
      [1.00 0.02]     0.95 1.05 1.25     >     1.00 1.00 1.00
      [1.00 0.10]     0.95 1.05 1.25     >     0.95 1.05 1.00
      [0.75 0.10]     0.75 0.95 1.25     >     0.75 0.75 0.75

%}


% registration and normalization options 
% Subject species: - 'human';'ape_greater';'ape_lesser';'monkey_oldworld';'monkey_newwold' (in development)
vbm.extopts.species      = 'human';  
% Affine PreProcessing (APP) with rough bias correction and brain extraction for special anatomies (nonhuman/neonates) - EXPERIMENTAL  
vbm.extopts.APP          = 0;   % 0 - none (default); 1 - APP with init. affreg; 2 - APP without init. affreg (standard in non human); 
vbm.extopts.vox          = 1.5; % voxel size for normalized data (EXPERIMENTAL:  inf - use Tempate values
vbm.extopts.bb           = [[-90 -126 -72];[90 90 108]]; % bounding box for normalized data (not yet working): inf - use Tempate values
vbm.extopts.darteltpm    = {fullfile(spm('dir'),'toolbox','vbm12','templates_1.50mm','Template_1_IXI555_MNI152.nii')};     % Indicate first Dartel template (Tempalte_1)
%vbm.extopts.darteltpm    = {fullfile(spm('dir'),'toolbox','vbm12','templates_1.50mm','Template_0_NKI174_MNI152_GS.nii')};  % Indicate first Shooting template (Template 0)
vbm.extopts.vbm12atlas   = {fullfile(spm('dir'),'toolbox','vbm12','templates_1.50mm','vbm12.nii')};                     % VBM atlas with major regions for VBM, SBM & ROIs
vbm.extopts.brainmask    = {fullfile(spm('Dir'),'toolbox','FieldMap','brainmask.nii')};                                 % Brainmask for affine registration
vbm.extopts.T1           = {fullfile(spm('Dir'),'toolbox','FieldMap','T1.nii')};                                        % T1 for affine registration

% surface options
vbm.extopts.pbtres       = 0.5;   % internal resolution for thickness estimation in mm: 
                                  % 1   - normal resolution
                                  % 0.5 - high res (default) 

% visualisation, print and debugging options
vbm.extopts.colormap     = 'BCGWHw'; % {'BCGWHw','BCGWHn'} and matlab colormaps {'jet','gray','bone',...};
vbm.extopts.print        = 1;     % Display and print results
vbm.extopts.verb         = 2;     % Verbose: 1 - default; 2 - details
vbm.extopts.debug        = 0;     % debuging option: 0 - default; 1 - write debugging files 
vbm.extopts.ignoreErrors = 1;     % catching preprocessing errors: 1 - catch errors (default); 0 - stop with error 
vbm.extopts.gui          = 1;     % use GUI 
vbm.extopts.expertgui    = 0;     % 0 - common user modus; 1 - expert modus with full GUI; 2 - experimental modus with experimental, unsafe functions!


% expert options - ROIs
%=======================================================================
% ROI maps from different sources mapped to Dartel VBM-space of IXI-template
%  { filename , refinement , tissue }
%  filename    = ''                                                     - path to the ROI-file
%  refinement  = ['brain','gm','none']                                  - refinement of ROIs in subject space
%  tissue      = {['csf','gm','wm','brain','none','']}                  - tissue classes for volume estimation
vbm.extopts.atlas       = { ... 
  fullfile(spm('dir'),'toolbox','vbm12','templates_1.50mm','hammers.nii')             'gm'    {'csf','gm','wm'} ; ... % good atlas based on 20 subjects
  fullfile(spm('dir'),'toolbox','vbm12','templates_1.50mm','neuromorphometrics.nii')  'gm'    {'csf','gm'};       ... % good atlas based on 35 subjects
 %fullfile(spm('dir'),'toolbox','vbm12','templates_1.50mm','ibsr.nii')     'brain' {'gm'}            ; ... % less regions than hammers, 18 subjects, low T1 image quality
 %fullfile(spm('dir'),'toolbox','vbm12','templates_1.50mm','anatomy.nii')  'none'  {'gm','wm'}       ; ... % ROIs requires further work >> use Anatomy toolbox
 %fullfile(spm('dir'),'toolbox','vbm12','templates_1.50mm','aal.nii')      'gm'    {'gm'}            ; ... % only one subject 
 %fullfile(spm('dir'),'toolbox','vbm12','templates_1.50mm','mori.nii')     'brain' {'gm'}            ; ... % only one subject, but with WM regions
  }; 








%=======================================================================
% PRIVATE PARAMETER (NOT FOR GENERAL USE)
%=======================================================================


% further maps
%=======================================================================
% Tissue classes 4-6 to create own TPMs
vbm.output.TPMC.native = 0; 
vbm.output.TPMC.warped = 0;
vbm.output.TPMC.mod    = 0;
vbm.output.TPMC.dartel = 0;

% partitioning atlas maps (vbm12 atlas)
vbm.output.atlas.native = 0; 
vbm.output.atlas.warped = 0; 
vbm.output.atlas.dartel = 0; 

% preprocessing changes map
% this is the map that include local changes by preprocessing   
vbm.output.pc.native = 0;
vbm.output.pc.warped = 0;
vbm.output.pc.mod    = 0;
vbm.output.pc.dartel = 0;

% tissue expectation map
% this is a map that describes that difference to the TPM
vbm.output.te.native = 0;
vbm.output.te.warped = 0;
vbm.output.te.mod    = 0; % meaningfull?
vbm.output.te.dartel = 0;

% IDs of the ROIs in the vbm12 atlas map (vbm12.nii). Do not change this!
vbm.extopts.LAB.NB =  0; % no brain 
vbm.extopts.LAB.CT =  1; % cortex
vbm.extopts.LAB.CB =  3; % Cerebellum
vbm.extopts.LAB.BG =  5; % BasalGanglia 
vbm.extopts.LAB.BV =  7; % Blood Vessels
vbm.extopts.LAB.TH =  9; % Hypothalamus 
vbm.extopts.LAB.ON = 11; % Optical Nerve
vbm.extopts.LAB.MB = 13; % MidBrain
vbm.extopts.LAB.BS = 13; % BrainStem
vbm.extopts.LAB.VT = 15; % Ventricle
vbm.extopts.LAB.NV = 17; % no Ventricle
vbm.extopts.LAB.HC = 19; % Hippocampus 
vbm.extopts.LAB.HD = 21; % Head
vbm.extopts.LAB.HI = 23; % WM hyperintensities
