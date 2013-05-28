function QAS = vbm_vol_t1qacalc(V,Y,Ym,Yp0)
% VBM Preprocessing T1 Quality Assurance
% ______________________________________________________________________
% Noise estimation ...
% just nifti/image, no further information ...
% 
%   QAS = vbm_vol_t1qa(V,Y,Ym,Yp0)
%
%   Input with X can be a set of filenames, a spm_vol-struct of volumes, 
%   or ONE volume.
%  
%   Y      = original MR input image
%   Ym     = bias corrected image
%   
%   Xp0Y   = tissue segmentation image
%            if numel(Xp0Y)==1, it will be used for all images!
%   XmT    = preprocessed (bias-corrected) version of the MR input
%            image XT
%
%   opt            = parameter structure
%   opt.verb       = verbose level  [ 0=nothing | 1=points | 2*=times ]
%   opt.redres     = resolution in mm for intensity scaling [ 4* ];
%   opt.write_csv  = final cms-file
%   opt.write_xml  = images base xml-file
%   opt.sortQATm   = sort QATm output
%   opt.recalc     =
%   opt.orgval     = original QAM results (no marks)
%   opt.avgfactor  = 
%   opt.prefix     = intensity scaled  image
%
% tissue peaks - std == noise (Sled 1998: I = O * bias / noise)
% ______________________________________________________________________
% - Um einen RMS test mit dem mT zu machen, k�nnten man ggf. sp�ter mal
%   soweit korrekte bilder mit einem st�rbias versehen und dann 
%   anschlie�end gucken wie gut man wieder zum original kommt ...
% ______________________________________________________________________
% Robert Dahnke 
% Structural Brain Mapping Group
% University Jena
%
% $Id$
% ______________________________________________________________________

  rev = '$Rev$';
    
  
%   % default options:
%   % --------------------------------------------------------------------
%   def.verb       = 2;         % verbose level    [ 0=nothing | 1=points | 2*=times ]
%   def.redres     = 4;         % resolution level for background estimation in mm [ 4* ]
%   def.write_csv  = 1;         % final cms-file
%   def.write_xml  = 1;         % images base xml-file
%   def.sortQATm   = 1;         % sort QATm output
%   def.recalc     = 1;         % 
%   def.orgval     = 0;         % original QAM results (no marks)
%   def.prefix     = 'vbm_';    % intensity scaled  image
%   
%   def.avgfactor  = 1.5;       % 
  
  %{
  % measures
  % --------------------------------------------------------------------
  def.tissue   = [ 1/3  1/6;  2/3  1/6;    1  1/6]; % ideal normalized tissue peak values 
  def.tisvola  = [ 300  300;  900  900;  600  600]; % absolut  expected tissue volumes 
  def.tisvolr  = [0.15  0.2; 0.45  0.2; 0.35  0.2]; % relative expected tissue volumes
  def.thicknes = [0.10  0.1; 2.50  0.5; 2.50  1.0]; % absolut  expected tickness
  def.CHvsCG   = [ 0.9  0.6;  0.1  0.4;    9    1]; % relation 
  def.QAM      = {
  % 'sortname'  'fieldname'             'marktpye'  markrange     save print help
  % 'sortname'  'fieldname'             'linear'    [best worst]    0 0    'use for most qa measures
  % 'sortname'  'fieldname'             'normal'    [mean std]      0 0    'use for most subject measures
    'vx_vol'    'res_vx_vol'            'linearb'   [0.75  3.00]    1 0    'voxel dimensions'
    'vol'       'res_vol'               'linearb'   [0.50  8.00]    1 1    'voxel volume'
    'isotr'     'res_isotropy'          'linearb'   [1.00   7/3]    1 1    'voxel isotropy'
    'noise'     'noise'                 'linearb'   [0.04  0.20]    1 1    'default noise = noise_WM / GW-contrast'
   %'noiseCG'   'noise_CG'              'linear'    [0.01  0.12]    1 0    'other noise measure ...
   %'noiseWM'   'noise_WM'              'linear'    [0.015 0.09]    1 0    'local std in YWM 
   %'noiseBG'   'noise_BG'              'linear'    [0.01  0.08]    1 0    'local std in YBG (problems for skull-striped data and ADNI) 
   %'noiseLG'   'noise_LG'              'linear'    [0.01  0.12]    1 0    'local std in the whole image      
    'bias'      'bias_WMstd'            'linearb'   [0.02  0.15]    1 1    'global std in the YWM'
   %'biasInh'   'bias_WMinhomogeneity'  'linear'    [1.00  0.50]    1 0    'WMinhomogeneity
   %'biasWME'   'bias_WMentropy'      	'linear'    [1.00  0.50]    1 0    'entropy in the YWM segment
   %'tis_med'   'tissue_median'         'normal'    def.tissue      1 1    'median within the tissue classes
    'tis_mean'  'tissue_mean'           'normalb'   def.tissue      1 1    'mean within the tissue classes'
   %'tis_std'   'tissue_std'            'linearb'   [1/12   1/6]    1 1    'std within the tissue classes
    'pc'        'prechange'             'linearb'   [0.05  1.00]    1 1    'changes between t1 and label'
    'te'        'te'                    'linearb'   [0.05  1.00]    1 1    'difference between template and label'
    'GWcon'     'contrast'              'linearb'   [1/3   0.05]    1 1    'contrast between tissue classe'
   %'Tcon'      'contrastT'             'linearb'   [0.30  0.05]    1 0    'contrast between tissue classes (correced for noise)
    'BGA'       'art_BGartifacts'       'linearb'   [0.05  0.50]    0 1    ''    
    'BGE'       'art_BGentropy'         'linearb'   [3.00  4.00]    0 1    ''
   %'comp'      'art_comp'              'linearb'   [   0   100]    0 1    ''
    'artWM'     'art_movesWM'           'linearb'   [0.00  0.10]    0 1    ''
    'artBG'     'art_movesBG'           'linearb'   [0.05  0.20]    0 1    ''
   %'Hbrain'    'hist_brain'            ''          []              0 0    'histogram brain'     
   %'HBG'       'hist_BG'               ''          []              0 0    'histogram background'
    'blurr'     'blurring'              'linearb'   [0.00  1.00]    0 1    ''
    'samp'      'sampling'              'linearb'   [0.00  1.00]    0 1    ''
    'gradient'  'mgradient'             'linearb'   [0.20  0.10]    0 1    ''
   % --Subjectrelated Data--
    'TIV'       'vol_TIV'               'normal'    [1500  1000]    1 1    'total intracranial volume (GM+YWM)'
    'CHvsCG'    'vol_CHvsGW'            'linear'    def.CHvsCG      1 1    'relation between brain and non brain'
    'absCGW'    'vol_abs_CGW'           'linearb'   def.tisvola     1 1    'absolut  tissue volume (CSF,GM,YWM)'
    'relCGW'    'vol_rel_CGW'           'linearb'   def.tisvolr     1 1    'relative tissue volume (CSF,GM,YWM)'
    'thick'     'dist_thickness'        'normalb'   def.thickness   1 1    'absolut thickness (CSF,GM,YWM)'
    'absdepth'  'dist_deptha'           'normalb'   [5.00  2.00]    0 0    'absolut sulcal depth'
    'reldpeth'  'dist_depthr'           'normalb'   [0.50  0.20]    0 0    'relative sulcal depth'
    };  
  if ~exist('opt','var'), opt=struct(); end
  opt = checkinopt(opt,def);
        
  
  
  % We comment some measures, because they are less important or overlap
  % with other measures and only increase runtime
  QAMs='struct(''scan'','''',''path'','''',''file'',''''';
  for i=1:size(opt.QAM,1)
    QAMs = [QAMs sprintf(',''%s'',%s',opt.QAM{i,2},opt.QAM{i,5})];  %#ok<AGROW>
  end
  QAS = eval([QAMs ');']);
  QAS = checkinopt(QA,QAS);
  QAM = struct();
  clear i QAMs;
  
  evalnormal  = @(x,best,worst,marks) min(9.5-eps,max(0,1 + (abs(best-x)./worst)*(marks-1))); %#ok<NASGU>
  evalnormalb = @(x,best,worst,marks) min(marks  ,max(1,1 + (abs(best-x)./worst)*(marks-1))); %#ok<NASGU>
  evallinear  = @(x,best,worst,marks) min(9.5-eps,max(0,1 + ((best-x)./diff([worst,best])*(marks-1)))); %#ok<NASGU>
  evallinearb = @(x,best,worst,marks) min(marks  ,max(1,1 + ((best-x)./diff([worst,best])*(marks-1)))); %#ok<NASGU>
  %}
  
  QAS = vbm_stat_marks('init');
  

  %% scan/file information
  QAS.FD.scan = V.fname;
  [QAS.FD.path,QAS.FD.file] = fileparts(V.fname);



  %% software
  A = ver;
  for i=1:length(A)
    if strcmp(A(i).Name,'Voxel Based Morphometry Toolbox'), QAS.SW.vbm    = A(i).Version; end
    if strcmp(A(i).Name,'Statistical Parametric Mapping'),  QAS.SW.spm    = A(i).Version; end
    if strcmp(A(i).Name,'MATLAB'),                          QAS.SW.matlab = A(i).Version; end
  end
  QAS.SW.QArev    = str2double(rev(7:end-2)); clear rev;
  QAS.SW.computer = computer;
  clear A;


  %% resolution
  if isfield(V,'mat'), vx_vol = sqrt(sum(V.mat(1:3,1:3).^2)); 
  else                 vx_vol = ones(1,3); 
  end
  QAS.QM.res_vx_vol    = vx_vol;
  QAS.QM.res_vol       = prod(abs(vx_vol));
  QAS.QM.res_isotropy  = max(vx_vol)./min(vx_vol);



  %% prepare image:
  % intensity scaling based on the YWM signal for both the original 
  % and the bias corrected images 
  %   ds('l2','',vx_vol,Ymi,YWM,Yi,Ymi,140)
  YWM   = vbm_vol_morph(Yp0>2.5,'lo'); 
  noise = vbm_stat_nanstat1d(Y(YWM),'mean'); 

  % intensity scaling for the original image Y
  Ys    = vbm_vol_smooth3X(single( Y),min(1,max(1/2,noise*20))); 
  Yi    = (Y   - min(Ys(:)))  / (median( Ys(YWM(:))) - min(Ys(:))); Yi(isnan(Yi(:))) = 0;  
  %iYs   = (Ys  - min(Ys(:)))  / (median( Ys(YWM(:))) - min(Ys(:))); iYs(isnan(iYs(:))) = 0;  
  clear Ys Y; 

  % intensity scaling for the corrected image Ym
  Yms   = vbm_vol_smooth3X(single(Ym),min(1,max(1/2,noise*20)));    
  Ymi   = (Ym  - min(Yms(:))) / (median(Yms(YWM(:))) - min(Yms(:))); Ymi(isnan(Ymi(:))) = 0; 
  %imYs  = (Yms - min(Yms(:))) / (median(Yms(YWM(:))) - min(Yms(:))); imYs(isnan(imYs(:))) = 0; 
  clear Ym Yms;
  clear noise; 

  % background and hull
  YHD   = vbm_vol_iscale(Ymi,'findhead')>0.5;


  % distance base redefinition of the background (relevant background)
  % image background can vary strongly and we are not interessed in
  % artifacts in some edges... our focus is the brain...
  YBGr  = vbm_vol_resize(Yp0,'reduce'); YBFrsize=size(YBGr); 
  YBGr  = vbm_vol_resize(YBGr,'reduce')>0.5;
  YHDr  = vbm_vol_resize(vbm_vol_resize(YHD,'reduce'),'reduce')>0.5;
  DBGr  = vbdist(single(YBGr))*mean(vx_vol*4); clear YBGr;  
  DHDr  = vbdist(single(YHDr))*mean(vx_vol*4);
  YBGRr = single(~YHDr & DBGr<50 & DHDr>3); clear DBGr DHDr YHDr; 
  YBGR  = vbm_vol_resize(vbm_vol_resize(YBGRr,'dereduce',YBFrsize),'dereduce',size(YHD))>0.5; 
  clear YBGRr YBFrsize;



  %% Tissue median, mean, and std
  % To estimte the peaks it is important to avoid the PVE for the
  % mean and median value, because in healty subjects the CSF is to 
  % strong affected. But for std it is ok!
  % The values are important for the contrast estimation, but we do
  % not have to store them, because mean and median are very similar
  % and the standard deviation is similar to our noise measure.
  fields = {'tissue','tissue_median','tissue_mean','tissue_std';
            'median','median'       ,'mean'       ,'std'};
  QAS.QM.tissue = [{zeros(1,3)} {zeros(1,3)}]; 
  for ci=1:3
    if ci==2
      M = Yp0(:)==ci; 
    else
      M = vbm_vol_morph(Yp0==ci,'lo'); M=M(:);
    end

    for fn=1:3
      if isfield(QAS.QM,(fields{1,fn})) 
        QAS.QM.(fields{1,fn}){1}(ci) = vbm_stat_nanstat1d( Yi(M),(fields{2,fn}));
        QAS.QM.(fields{1,fn}){2}(ci) = vbm_stat_nanstat1d(Ymi(M),(fields{2,fn}));
      end
    end
    if isfield(QAS.QM,'tissue_std')
      MPVE = round(Yp0(:))==ci; 
      QAS.QM.tissue_std{1}(ci)    = vbm_stat_nanstat1d( Yi(MPVE),'std');
      QAS.QM.tissue_std{2}(ci)    = vbm_stat_nanstat1d(Ymi(MPVE),'std');
    end
  end
  clear M MPVE mi ci;



  %% Contrast
  % Tissue contrast can change for different sequences. Because we
  % normalize the YBG intensity to 0 and the YWM intensity to 1, the
  % CSF and the YWM peak should be somewhere inbetween. This means
  % that if we want to have a similar contrast a value of 1/3 for
  % CSF and 2/3 for GM represents the optimum. Mostly the CSF peak 
  % have a similar distance to the GM peak, like the GM peak to the 
  % YWM Because, i.e. YWM=1 and GM=0.8 will lead to CSF~0.6. Because 
  % for our purpose the differenciation between GM and YWM is more 
  % important, lower values of the CSF and GM peaks like GM=0.5 and
  % CSF=0.1 are prefered.
  % But for these high contrast images, the kmeans run into trouble.
  % In the average case only the differencialisation between GM and
  % CSF is a little bit reduces, but in the worst case the kmeans
  % will identify the wrong peaks and detect the GM-YWM peak of the
  % PVE and subcortical structures as GM, and the GM peak then as 
  % CSF peak resulting in total bullshit.
  % Normally, the standard deviation of the tissue peaks play also a
  % important rule to describe the differenciability of the classes,
  % but because this measure is very similar to the noise we do not
  % include it here!
  if isfield(QAS.QM,'contrast') % tissue contrast for BCGW
    QAS.QM.contrastT = [{diff([0 QAS.QM.tissue{1}])}, ...
                        {diff([0 QAS.QM.tissue{2}])}];
  end
  if isfield(QAS.QM,'contrastT') % only GW-contrast
    QAS.QM.contrast  = [diff(QAS.QM.tissue{1}(2:3)), ...
                        diff(QAS.QM.tissue{2}(2:3))];
  end    



  %% Preprocessing Change map results
  if isfield(QAS.QM,'vbm_change')
    QAY = vbm_vol_iscale(Yi,'gCGW',vx_vol,QAS.QM.tissue{1});

    Ypc = abs(min(7/6,QAY.*(Yp0>0)) - Yp0/3); 
    QAS.QM.vbm_change(1) = sum(Ypc(:)) / sum(Yp0(:)>0);
    clear QAY;

    Ypc = abs(min(7/6,Ymi .*(Yp0>0)) - Yp0/3); 
    QAS.QM.vbm_change(2) = sum(Ypc(:)) / sum(Yp0(:)>0);

    %QAS.QM = rmfield(QAS.QM,'tissue'); 
    clear Ypc;
  end



  %% histograms on low resolution to reduce noise effects
  % Histograms are required later for the entropy
  Yir  = vbm_vol_resize(Yi    ,'reduce');
  Ymir = vbm_vol_resize(Ymi   ,'reduce');
  YHDr = vbm_vol_resize(single(YHD),'reduce')>0.5;
  YBGr = vbm_vol_resize(single(YBGR),'reduce')>0.5;
  YWMr = vbm_vol_resize(single(Yp0>2.5),'reduce')>0.5;
  Ytmp =  Yir( YWMr); HN = hist(Ytmp,0:0.01:10); HN_WM{1} = HN/sum(HN); 
  Ytmp =  Yir( YBGr); HN = hist(Ytmp,0:0.01:10); HN_B{1}  = HN/sum(HN); 
  Ytmp =  Yir(~YHDr); HN = hist(Ytmp,0:0.01:10); HN_BG{1} = HN/sum(HN); 
  Ytmp = Ymir( YWMr); HN = hist(Ytmp,0:0.01:10); HN_WM{2} = HN/sum(HN); 
  Ytmp = Ymir( YBGr); HN = hist(Ytmp,0:0.01:10); HN_B{2}  = HN/sum(HN); 
  Ytmp = Ymir(~YHDr); HN = hist(Ytmp,0:0.01:10); HN_BG{2} = HN/sum(HN); 
  if isfield(QAS.QM,'hist_brain'), QAS.QM.hist_brain = HN_B;  end
  if isfield(QAS.QM,'hist_BG'),    QAS.QM.hist_BG    = HN_BG; end
  clear Ytmp HN Yir Ymir YHDr YWMr;



  %% noise estimation
  % All measures seam to produce similar results, although they
  % measure noise in a different way or in different regions.
  % Noise estimiation in the background doen't work in images that
  % were skull-stripped or special preprocessed like ADNI.
  % For the standard noise variable the signal is given by the
  % GW-contrast that is more important than CG- or BC-Contrast.
  QAS.QM.noise = [estimateNoiseLevel( Yi,YWM) / QAS.QM.contrast(1), ...
                  estimateNoiseLevel(Ymi,YWM) / QAS.QM.contrast(2)];   
  if isfield(QAS.QM,'noise_WM')  % within the YWM - standard noise
    QAS.QM.noise_WM = [estimateNoiseLevel( Yi,YWM), ...
                       estimateNoiseLevel(Ymi,YWM)]; 
  end                
  if isfield(QAS.QM,'noise_BG')  % background
    QAS.QM.noise_BG = [estimateNoiseLevel(Yi,YBGR), ...
                       estimateNoiseLevel(Ymi,YBGR)];
  end  
  if isfield(QAS.QM,'noise_CG')  % full CG approach
    QAS.QM.noise_CG = [cg_noise_estimation(Yi), ...
                       cg_noise_estimation(Ymi)];
  end    
  if isfield(QAS.QM,'noise_LG')  % full in low gradient regions
    QAS.QM.noise_LG = [estimateNoiseLevel(Yi), ...
                       estimateNoiseLevel(Ymi)];
  end     



  %% Bias/Inhomogeneity 
  % Bias estimation on lower level to reduce noise and other artifacts.
  % Inhomogeneity needs a good segmentation, because of the use of the
  % minimum and maximum. The YWM-Entropy show the right direction but 
  % the values vary strongly for different scans...
  % ############# restbias als QA f�rs YWM segment!
  Yir   = vbm_vol_resize(Yi  ,'reduce');
  Ymir  = vbm_vol_resize(Ymi ,'reduce');
  YWMr  = vbm_vol_resize(single(Yp0>2.5),'reduce')>0.5;
  if isfield(QAS.QM,'bias_WMstd')
    QAS.QM.bias_WMstd = [max(0,std( Yir(YWMr(:)))),...
                         max(0,std(Ymir(YWMr(:))))];
  end
  clear Yir Ymir YWMr;
  if isfield(QAS.QM,'bias_WMinhomogeneity')
    QAS.QM.bias_WMinhomogeneity = ...
      [1 - (max( Ytmp) - min( Ytmp)) / (min( Ytmp) + max( Ytmp)), ...
       1 - (max(imYM) - min(imYM)) / (min(imYM) + max(imYM))];
  end
  if isfield(QAS.QM,'bias_WMentropy')
    QAS.QM.bias_WMentropy = ...
      [-vbm_stat_nanstat1d(HN_BG{1}.*log(HN_BG{1}),'sum'), ...
       -vbm_stat_nanstat1d(HN_BG{2}.*log(HN_BG{2}),'sum')];
  end



  %% EXPERIMENTAL QAMs
  % Here we have the focus on motion and other artifacts that are 
  % amybe good detectable in the background. 
  % Futhermore, we try do describe sharp and unsharp images. I.e.
  % averaging with a bad realignment properties will inrease SNR,
  % but reduce the sharpness of the edges.
  %
  % Artifacts:
  % Interestingly the entropy works much better for the background,
  % but it also depend on noise and other artifacts - more an overall
  % measure.
  if isfield(QAS.QM,'art_BGartifacts')
    QAS.QM.art_BGartifacts = [std(Yi(YBGR)) std(Ymi(YBGR))]; 
  end
  if isfield(QAS.QM,'art_BGentropy')
    QAS.QM.art_BGentropy = [ ...
      -vbm_stat_nanstat1d(HN_WM{1}.*log(HN_WM{1}),'sum'), ...
      -vbm_stat_nanstat1d(HN_WM{2}.*log(HN_WM{2}),'sum')];
  end
  if isfield(QAS.QM,'Bentropy')
    QAS.QM.Bentropy = [...
      -vbm_stat_nanstat1d(HN_B .*log(HN_B ),'sum'), ... 
      -vbm_stat_nanstat1d(HN_B .*log(HN_B ),'sum')]; 
  end


  % artifacts in the YWM
  if isfield(QAS.QM,'art_movesWM')
    WI1=vbm_vol_localstat( Yi,YWM,1,4); WI2=vbm_vol_localstat( Yi,YWM,2,4);
    QAS.QM.art_movesWM(1) = nanmean(abs(WI2(YWM(:))-WI1(YWM(:))));
    WI1=vbm_vol_localstat(Ymi,YWM,1,4); WI2=vbm_vol_localstat(Ymi,YWM,2,4);
    QAS.QM.art_movesWM(2) = nanmean(abs(WI2(YWM(:))-WI1(YWM(:))));
    clear WI1;
  end
  % artifacts in the relevant YBG
  if isfield(QAS.QM,'art_movesBG')
    WI1=vbm_vol_localstat(Yi,YBGR,1,4); WI2=vbm_vol_localstat(Yi,YBGR,2,4); 
    QAS.QM.art_movesBG(1) = nanmean(abs(WI2(YBGR(:))-WI1(YBGR(:))));
    WI1=vbm_vol_localstat(Ymi,YBGR,1,4); WI2=vbm_vol_localstat(Ymi,YBGR,2,4); 
    QAS.QM.art_movesBG(2) = nanmean(abs(WI2(YBGR(:))-WI1(YBGR(:))));
    clear WI1;
  end

  if isfield(QAS.QM,'art_comp')
    QAS.QM.art_comp = [getComp(Yi,Yp0>0.5) getComp(imYs,Yp0>0.5)]; % iYs
  end



  %% Sharpness:
  if isfield(QAS.QM,'gradient') || isfield(QAS.QM,'mgradient') 
    grad{1} = edge( Yi,Yp0,QAS.QM.res_vol); % iYs
    grad{2} = edge(Ymi,Yp0,QAS.QM.res_vol); % imYs
    QAS.QM.mgradient = [grad{1}(2) grad{2}(2)];
  end


  %% Smooth vs unsmooth & resampling:
  % A image without high frequencies can reduce and reinterpolatet with lower differenz.
  if isfield(QAS.QM,'blurring') 
    iYS  = vbm_vol_smooth3X(Yi);  % iYs 
    imYS = vbm_vol_smooth3X(Ymi); % imYs
    QAS.QM.blurring = [ ...
      vbm_stat_nanstat1d( Yi(Yp0(:)>0.5) -  iYS(Yp0(:)>0.5),'std'), ... % iYs
      vbm_stat_nanstat1d(Ymi(Yp0(:)>0.5) - imYS(Yp0(:)>0.5),'std')];    % imYs
    clear imYS iYS;
  end
  if isfield(QAS.QM,'sampling') 
    Yir  = vbm_vol_resize( Yi,'reduce');  iYR = vbm_vol_resize( Yir,'dereduce',size(imYs)); % iYs
    Ymir = vbm_vol_resize(Ymi,'reduce'); imYR = vbm_vol_resize(Ymir,'dereduce',size(imYs)); % imYs
    QAS.QM.sampling = [ ...
      vbm_stat_nanstat1d( Yi(Yp0(:)>0.5) -  iYR(Yp0(:)>0.5),'std'), ... % iYs
      vbm_stat_nanstat1d(Ymi(Yp0(:)>0.5) - imYR(Yp0(:)>0.5),'std')];    % imYs
    clear iYsr imYsr Yir imYR;
  end  
  clear Ytmp HN;
      
end
function grad = edge(Ymi,Yp0,res_vol)
  [gx,gy,gz] = vbm_vol_gradient3(single(Ymi)); gT=abs(gx)+abs(gy)+abs(gz); clear gx gy gz; 
  WMP = vbm_vol_morph(Yp0>2.5,'dilate',1); 
  WMS = vbm_vol_morph(Yp0>2.5,'erode',1)==1;
  M   = Yp0(:)>0.5 & ~WMS(:) & (gT(:)>0.1) & (gT(:)<0.4) & (Ymi(:)>0.2); 
  grad(1) = res_vol .* (vbm_stat_nanstat1d(gT(M),'mean') - vbm_stat_nanstat1d(gT(M),'std'));
  M   = WMP(:) & ~WMS(:) & (gT(:)>0.1) & (gT(:)<0.4) & (Ymi(:)>0.8); 
  grad(2) = res_vol .* (vbm_stat_nanstat1d(gT(M),'mean') - vbm_stat_nanstat1d(gT(M),'std'));
end
function noise = estimateNoiseLevel(T,M)
  T   = single(T);
  TS  = smooth3(T); 
  [gx,gy,gz] = vbm_vol_gradient3(TS);
  G   = abs(gx)+abs(gy)+abs(gz); clear gx gy gz; %G=G./T; 
  Gth = vbm_stat_nanstat1d(G,'mean');
  if ~exist('M','var')
    M   =  TS>0 & (TS<0.3 | G<Gth);
%    M   = vbm_vol_morph(vbm_vol_morph(TS<0.3 | G<Gth,'open'),'close');
  else
    M   = M & TS>0 & (TS<0.3 | G<Gth);
%   M   = M & vbm_vol_morph(vbm_vol_morph(TS<0.3 | G<Gth,'open'),'close');
  end
  
  TSD = vbm_vol_localstat(T,M,1,4); noise  = vbm_stat_nanstat1d(TSD(TSD>0),'mean'); 
end
function noise = getNoiselevel(T,s,m,range) %#ok<DEFNU>
  if ~exist('s','var'),     s=5; end              % number of test levels [5]
  if ~exist('m','var'),     m=0; end              % median or mean [ 0* | 1 ]
  if ~exist('range','var'), range=[0.4,0.8]; end  % intensity test range
  
  noisehist=zeros(1,s); 
  for i=1:s; noisehist = double(cg_noise_estimation(T .* (T>(range(1)+(range(2)-range(1))*i/s)))); end
  
  if m==0, noise = median(noisehist); else noise=mean(noisehist); end
  
  function h = cg_noise_estimation(ima)
    % FORMAT h = cg_noise_estimation(ima)
    %
    % 
    % ***************************************************************************
    %  The noise estimation is described in:                                       
    %                                                                         
    %  S. Aja-Fern�ndez, A. Trist�n-Vega, C. Alberola-L�pez.     
    %  Noise estimation in single- and multiple-coil magnetic resonance data 
    %  based on statistical models (2009).
    %  Magnetic Resonance Imaging, 27, 1397-1409.                                                             
    % ***************************************************************************
    %
    %_______________________________________________________________________
    % Christian Gaser
    % $Id$

    % estimate local mean
    k = 3;
    localMean = (convn(single(ima),ones(k,k,k),'same')/k^3);

    % find non-zero regions
    ind = find(localMean>0);

    % If image has non-zero background (we check that less than 5% of the image are zero) 
    % we can assume Rayleigh PDF in the background and noise estimation can be based on
    % mode of local mean (equation 11 in Aja-Fern�ndez et al. 2009)
    if 0 && length(ind)>0.9*numel(ima)
      h = sqrt(2/pi)*moda(localMean(ind),1000);
    else % otherwise use mode of local variance (equation 15 in Aja-Fern�ndez et al. 2009)
      localVar = (convn(single(ima).^2,ones(k,k,k),'same')/k^3) - localMean.^2;
      h = sqrt(moda(localVar(ind),1000));
    end

  end

  function m = moda(u,N)
  % MODA   Mode of a distribution
  %
  %    m=MODE(u,N) calculates the mode of the set of data "u" using the histogram.
  %    To avoid outliers, for the calculation are only taken into account those
  %    values less than mean+2sigma;
  %
  %    INPUT:
  %
  %	- u (set of data)
  %       - N: Number of points for the histogram. If N=0 then 5000 points are
  %            considered
  %
  %   Author: Santiago Aja Fernandez
  %   LOCAL STATISTICS TOOLBOX
  %
  %   Modified: Feb 01 2008
  %

  if N==0
    N = 1000;
  end

  u = single(u(:));

  M1 = mean(u);
  V1 = std(u);
  C2 = u(u<=(M1+2*V1));
  [h,x] = hist(C2,N);
  [M,M2] = max(h);

  m = x(M2);

  end
end
function comp = getComp(T,B,range,stepsize)
  if ~exist('range','var'),     range     = [0.8 0.9]; end
  if ~exist('stepsize','var'),  stepsize  = 0.05; end
  
  steps = range(1):stepsize:range(2);
  num   = zeros(1,numel(steps));

  for i=1:numel(steps)
    M = vbm_vol_morph(B & (T>steps(i)),'o');
    [ROI,num] = spm_bwlabel(double(M),6);
  end

  comp = mean(num);
end