function opts = cg_vbm_opts
% Configuration file for VBM options
%
% Christian Gaser
% $Id$
%#ok<*AGROW>

%_______________________________________________________________________
tpm         = cfg_files;
tpm.tag     = 'tpm';
tpm.name    = 'Tissue Probability Map';
tpm.filter  = 'image';
tpm.ufilter = '.*';
tpm.def     =  @(val)cg_vbm_get_defaults('opts.tpm', val{:});
tpm.num     = [1 1];
tpm.help    = {
  'Select the tissue probability image for this class. These should be maps of eg grey matter, white matter or cerebro-spinal fluid probability. A nonlinear deformation field is estimated that best overlays the tissue probability maps on the individual subjects'' image. The default tissue probability maps are modified versions of the ICBM Tissue Probabilistic Atlases. These tissue probability maps are kindly provided by the International Consortium for Brain Mapping, John C. Mazziotta and Arthur W. Toga. http://www.loni.ucla.edu/ICBM/ICBM_TissueProb.html.'
  ''
  'The original data are derived from 452 T1-weighted scans, which were aligned with an atlas space, corrected for scan inhomogeneities, and classified into grey matter, white matter and cerebrospinal fluid. These data were then affine registered to the MNI space and down-sampled to 2mm resolution.Rather than assuming stationary prior probabilities based upon mixing proportions, additional information is used, based on other subjects'' brain images. Priors are usually generated by registering a large number of subjects together, assigning voxels to different tissue types and averaging tissue classes over subjects. The algorithm used here will employ these priors for the first initial segmentation and normalization. Six tissue classes are used: grey matter, white matter, cerebro-spinal fluid, bone, non-brain soft tissue and air outside of the head and in nose, sinus and ears. These maps give the prior probability of any voxel in a registered image being of any of the tissue classes - irrespective of its intensity.The model is refined further by allowing the tissue probability maps to be deformed according to a set of estimated parameters. This allows spatial normalisation and segmentation to be combined into the same model.Selected tissue probability map must be in multi-volume nifti format and contain all six tissue priors. '
''
};

%------------------------------------------------------------------------
% various options for estimating the segmentations
%------------------------------------------------------------------------

ngaus         = cfg_entry;
ngaus.tag     = 'ngaus';
ngaus.name    = 'Gaussians per class';
ngaus.strtype = 'n';
ngaus.num     = [1 6];
ngaus.def     = @(val)cg_vbm_get_defaults('opts.ngaus', val{:});
ngaus.help    = {
'The number of Gaussians used to represent the intensity distribution for each tissue class can be greater than one. In other words, a tissue probability map may be shared by several clusters. The assumption of a single Gaussian distribution for each class does not hold for a number of reasons. In particular, a voxel may not be purely of one tissue type, and instead contain signal from a number of different tissues (partial volume effects). Some partial volume voxels could fall at the interface between different classes, or they may fall in the middle of structures such as the thalamus, which may be considered as being either grey or white matter. Various other image segmentation approaches use additional clusters to model such partial volume effects. These generally assume that a pure tissue class has a Gaussian intensity distribution, whereas intensity distributions for partial volume voxels are broader, falling between the intensities of the pure classes. Unlike these partial volume segmentation approaches, the model adopted here simply assumes that the intensity distribution of each class may not be Gaussian, and assigns belonging probabilities according to these non-Gaussian distributions. Typical numbers of Gaussians could be two for grey matter, two for white matter, two for CSF, three for bone, four for other soft tissues and two for air (background).'
''
'Note that if any of the Num. Gaussians is set to non-parametric, then a non-parametric approach will be used to model the tissue intensities. This may work for some images (eg CT), but not others - and it has not been optimised for multi-channel data. Note that it is likely to be especially problematic for images with poorly behaved intensity histograms due to aliasing effects that arise from having discrete values on the images.'
''
};


%------------------------------------------------------------------------

biasreg        = cfg_menu;
biasreg.tag    = 'biasreg';
biasreg.name   = 'Bias regularisation';
biasreg.def    = @(val)cg_vbm_get_defaults('opts.biasreg', val{:});
biasreg.labels = {
  'No regularisation (0)','Extremely light regularisation (0.00001)','Very light regularisation (0.0001)','Light regularisation (0.001)','Medium regularisation (0.01)','Heavy regularisation (0.1)','Very heavy regularisation (1)','Extremely heavy regularisation (10)'};
biasreg.values = {0, 0.00001, 0.0001, 0.001, 0.01, 0.1, 1.0, 10};
biasreg.help   = {
  'MR images are usually corrupted by a smooth, spatially varying artifact that modulates the intensity of the image (bias). These artifacts, although not usually a problem for visual inspection, can impede automated processing of the images.An important issue relates to the distinction between intensity variations that arise because of bias artifact due to the physics of MR scanning, and those that arise due to different tissue properties.  The objective is to model the latter by different tissue classes, while modelling the former with a bias field. We know a priori that intensity variations due to MR physics tend to be spatially smooth, whereas those due to different tissue types tend to contain more high frequency information. A more accurate estimate of a bias field can be obtained by including prior knowledge about the distribution of the fields likely to be encountered by the correction algorithm. For example, if it is known that there is little or no intensity non-uniformity, then it would be wise to penalise large values for the intensity non-uniformity parameters. This regularisation can be placed within a Bayesian context, whereby the penalty incurred is the negative logarithm of a prior probability for any particular pattern of non-uniformity.Knowing what works best should be a matter of empirical exploration.  For example, if your data has very little intensity non-uniformity artifact, then the bias regularisation should be increased.  This effectively tells the algorithm that there is very little bias in your data, so it does not try to model it.'
''
};


%------------------------------------------------------------------------

biasfwhm        = cfg_menu;
biasfwhm.tag    = 'biasfwhm';
biasfwhm.name   = 'Bias FWHM';
biasfwhm.labels = {
  '30mm cutoff','40mm cutoff','50mm cutoff','60mm cutoff','70mm cutoff','80mm cutoff','90mm cutoff','100mm cutoff','110mm cutoff','120mm cutoff','130mm cutoff','140mm cutoff','150mm cutoff','No correction'};
biasfwhm.values = {30,40,50,60,70,80,90,100,110,120,130,140,150,Inf};
biasfwhm.def    = @(val)cg_vbm_get_defaults('opts.biasfwhm', val{:});
biasfwhm.help   = {
  'FWHM of Gaussian smoothness of bias. '
  ''
  'If your intensity non-uniformity is very smooth, then choose a large FWHM. This will prevent the algorithm from trying to model out intensity variation due to different tissue types. The model for intensity non-uniformity is one of i.i.d. Gaussian noise that has been smoothed by some amount, before taking the exponential. Note also that smoother bias fields need fewer parameters to describe them. This means that the algorithm is faster for smoother intensity non-uniformities.'
''
};

%------------------------------------------------------------------------

warpreg         = cfg_entry;
warpreg.def     = @(val)cg_vbm_get_defaults('opts.warpreg', val{:});
warpreg.tag     = 'warpreg';
warpreg.name    = 'Warping Regularisation';
warpreg.strtype = 'r';
warpreg.num     = [1 5];
warpreg.help    = {
  'The objective function for registering the tissue probability maps to the image to process, involves minimising the sum of two terms. One term gives a function of how probable the data is given the warping parameters. The other is a function of how probable the parameters are, and provides a penalty for unlikely deformations. Smoother deformations are deemed to be more probable. The amount of regularisation determines the tradeoff between the terms. Pick a value around one.  However, if your normalised images appear distorted, then it may be an idea to increase the amount of regularisation (by an order of magnitude). More regularisation gives smoother deformations, where the smoothness measure is determined by the bending energy of the deformations. '
};


%------------------------------------------------------------------------

affreg        = cfg_menu;
affreg.tag    = 'affreg';
affreg.name   = 'Affine Regularisation';
affreg.labels = {'No Affine Registration','ICBM space template - European brains','ICBM space template - East Asian brains','Average sized template','No regularisation'};
affreg.values = {'','mni','eastern','subj','none'};
affreg.def    = @(val)cg_vbm_get_defaults('opts.affreg', val{:});
affreg.help   = {
  'The procedure is a local optimisation, so it needs reasonable initial starting estimates. Images should be placed in approximate alignment using the Display function of SPM before beginning. A Mutual Information affine registration with the tissue probability maps (D''Agostino et al, 2004) is used to achieve approximate alignment. Note that this step does not include any model for intensity non-uniformity. This means that if the procedure is to be initialised with the affine registration, then the data should not be too corrupted with this artifact.If there is a lot of intensity non-uniformity, then manually position your image in order to achieve closer starting estimates, and turn off the affine registration.Affine registration into a standard space can be made more robust by regularisation (penalising excessive stretching or shrinking).  The best solutions can be obtained by knowing the approximate amount of stretching that is needed (e.g. ICBM templates are slightly bigger than typical brains, so greater zooms are likely to be needed). For example, if registering to an image in ICBM/MNI space, then choose this option.  If registering to a template that is close in size, then select the appropriate option for this.'
''
};

%------------------------------------------------------------------------

samp         = cfg_entry;
samp.tag     = 'samp';
samp.name    = 'Sampling distance';
samp.strtype = 'r';
samp.num     = [1 1];
samp.def    = @(val)cg_vbm_get_defaults('opts.samp', val{:});
samp.help   = {
  'This encodes the approximate distance between sampled points when estimating the model parameters. Smaller values use more of the data,  but the procedure is slower and needs more memory. Determining the "best" setting involves a compromise between speed and accuracy.'
''
};

%------------------------------------------------------------------------

opts      = cfg_branch;
opts.tag  = 'opts';
opts.name = 'Options for initial SPM12 affine registration';
opts.val  = {tpm,affreg};
opts.help = {
  'Various options can be adjusted in order to improve the performance of the initial SPM12 registration that is used as starting point for the VBM12 segmentation. Knowing what works best should be a matter of empirical exploration. However, most of the option work very well for a large variety of data and only for of high-field MR scanner bias regularization might be adapted to a lower value in the file cg_vbm_defaults.m. Furthermore, for children data I strongly recommend to use customized TPMs created using the Template-O-Matic toolbox.'};

