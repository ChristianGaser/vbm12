function stools = cg_vbm_stools(expert)
%_______________________________________________________________________
% wrapper for calling VBM surface utilities
%_______________________________________________________________________
% Robert Dahnke and Christian Gaser
% $Id$
%_______________________________________________________________________



%% Surface covariance and quality assurance
%-----------------------------------------------------------------------
  data_surf_cov         = cfg_files;
  data_surf_cov.tag     = 'data_surf';
  data_surf_cov.name    = 'Sample';
  data_surf_cov.filter  = 'gifti';
  data_surf_cov.ufilter = 'resampled';
  data_surf_cov.num     = [1 Inf];
  data_surf_cov.help    = {'Select resampled surfaces parameter files.'};
  
  data_xml = cfg_files;
  data_xml.name = 'XML files';
  data_xml.tag  = 'data_xml';
  data_xml.filter = 'xml';
  data_xml.num  = [1 Inf];
  data_xml.help   = {
  'These are the xml-files that are saved during segmentation. Please note, that the order of the xml-files must be the same as the other data files..'};

  
  sample_cov         = cfg_repeat;
  sample_cov.tag     = 'sample';
  sample_cov.name    = 'Data';
  sample_cov.values  = {data_surf_cov};
  sample_cov.num     = [1 Inf];
  sample_cov.help = {...
  'Specify data for each sample. If you specify different samples the mean correlation is displayed in seperate boxplots for each sample.'};

  qam         = cfg_repeat;
  qam.tag     = 'qam';
  qam.name    = 'Load quality measures';
  qam.values  = {data_xml};
  qam.num     = [0 Inf];
  qam.help    = {'This option allows to also load the quality measures that are saved in the xml-files. Please note, that the order of the xml-files must be the same as the other data files.'};

  c         = cfg_entry;
  c.tag     = 'c';
  c.name    = 'Vector';
  c.help    = {'Vector of nuisance values'};
  c.strtype = 'r';
  c.num     = [Inf 1];

  transform         = cfg_repeat;
  transform.tag     = 'transform';
  transform.name    = 'Nuisance variable';
  transform.values  = {c};
  transform.num     = [0 Inf];
  transform.help    = {'This option allows for the specification of nuisance effects to be removed from the data. A potential nuisance parameter can be age. In this case the variance explained by age will be removed prior to the calculation of the correlation.'};

  check_mesh_cov      = cfg_exbranch;
  check_mesh_cov.tag  = 'check_mesh_cov';
  check_mesh_cov.name = 'Check sample homogeneity of surfaces';
  check_mesh_cov.val  = {sample_cov,qam,transform};
  check_mesh_cov.prog = @cg_check_cov;
  check_mesh_cov.help = {
  'If you have a reasonable sample size artefacts are easily overseen. In order to identify surfaces with poor image quality or even artefacts you can use this function. Surfaces have to be rsampled to the template space (e.g. normalized images). The idea of this tool is to check the correlation of all files across the sample.'
  ''
  'The correlation is calculated between all images and the mean for each image is plotted using a boxplot and the indicated filenames. The smaller the mean correlation the more deviant is this surface from the sample mean. In the plot outliers from the sample are usually isolated from the majority of images which are clustered around the sample mean. The mean correlation is plotted at the y-axis and the x-axis reflects the image order. Images are plotted from left to right which is helpful if you have selected the images in the order of different sub-groups.'};

    
  
  
%% surface measures
%-----------------------------------------------------------------------  
  data_surf_extract         = cfg_files;
  data_surf_extract.tag     = 'data_surf';
  data_surf_extract.name    = 'Sample';
  data_surf_extract.filter  = 'gifti';
  data_surf_extract.ufilter = '^[lr]h.central';
  data_surf_extract.num     = [1 Inf];
  data_surf_extract.help    = {'Select surfaces to extract values.'};
  
  GI        = cfg_menu;
  GI.name   = 'Gyrification index';
  GI.tag    = 'GI';
  GI.labels = {'none','yes'};
  GI.values = {0,1};
  GI.val    = {1};
  GI.help   = {
    'Extract gyrification index (GI) based on absolute mean curvature. The method is described in Luders et al. NeuroImage, 29: 1224-1230, 2006.'
  };

  FD        = cfg_menu;
  FD.name   = 'Cortical complexity (fractal dimension)';
  FD.tag    = 'FD';
  FD.labels = {'none','yes'};
  FD.values = {0,1};
  FD.val    = {0};
  FD.help   = {
    'Extract Cortical complexity (fractal dimension) which is described in Yotter et al. Neuroimage, 56(3): 961-973, 2011.'
    ''
    'Warning: Estimation of cortical complexity is very slow!'
    ''
  };

  SD        = cfg_menu;
  SD.name   = 'Sulcus depth';
  SD.tag    = 'SD';
  SD.labels = {'none','yes'};
  SD.values = {0,1};
  SD.val    = {1};
  SD.help   = {
    'Extract log10-transformed sulcus depth based on the euclidian distance between the central surface and its convex hull.'
    ''
    'Log-transformation is used to render the data more normally distributed.'
    ''
  };

  SA        = cfg_menu;
  SA.name   = 'Surface area';
  SA.tag    = 'SA';
  SA.labels = {'none','yes'};
  SA.values = {0,1};
  SA.val    = {1};
  SA.help   = {
    'Extract log10-transformed local surface area using re-parameterized tetrahedral surface. The method is described in Winkler et al. NeuroImage, 61: 1428–1443, 2012.'
    ''
    'Log-transformation is used to render the data more normally distributed.'
    ''
  };

  surfextract      = cfg_exbranch;
  surfextract.tag  = 'surfextract';
  surfextract.name = 'Extract surface parameters';
  surfextract.val  = {data_surf_extract,GI,FD,SD};
  surfextract.prog = @vbm_surf_parameters;
  surfextract.help = {'Using this option several surface parameters can be extracted that can be further analyzed.'};




%% extract volumetric data
%-----------------------------------------------------------------------  
  v2s.datafieldname         = cfg_entry;
  v2s.datafieldname.tag     = 'datafieldname';
  v2s.datafieldname.name    = 'Texture Name';
  v2s.datafieldname.strtype = 's';
  v2s.datafieldname.num     = [1 Inf];
  v2s.datafieldname.val     = {'intensity'};
  v2s.datafieldname.help    = {'Name of the extracted data.'};
 
  
  % Mapping function - Volume extration interpolation type
  %---------------------------------------------------------------------  
  v2s.map.mean         = cfg_branch;
  v2s.map.mean.tag     = 'mean';
  v2s.map.mean.name    = 'Mean';
  v2s.map.mean.help    = {
    ''
  };

  v2s.map.median         = cfg_branch;
  v2s.map.median.tag     = 'median';
  v2s.map.median.name    = 'Median';
  v2s.map.median.help    = {
    ''
  };

  v2s.map.range         = cfg_entry;
  v2s.map.range.tag     = 'range';
  v2s.map.range.name    = 'Sampling Intensity Range';
  v2s.map.range.strtype = 'r';
  v2s.map.range.val{1}  = [-3.40282e+38 3.40282e+38];
  v2s.map.range.num     = [1 1];
  v2s.map.range.help    = {
    'If any value is out of range values will be counted only until this point.'
    ''
  };

  v2s.map.min         = cfg_files;
  v2s.map.min.tag     = 'min';
  v2s.map.min.name    = 'Minimum (possible mask images)';
  v2s.map.min.filter  = 'nifti';
  v2s.map.min.ufilter = '.*';
  v2s.map.min.num     = [0 Inf];
  v2s.map.min.val{1}  = ''; 
  v2s.map.min.help    = {
    ''
    };

  v2s.map.max         = cfg_files;
  v2s.map.max.tag     = 'max';
  v2s.map.max.name    = 'Maximum (possible mask images)';
  v2s.map.max.filter  = 'nifti';
  v2s.map.max.ufilter = '.*';
  v2s.map.max.num     = [0 Inf];
  v2s.map.max.val{1}  = ''; 
  v2s.map.max.help    = {
    ''
  };

  v2s.map.exp         = cfg_entry;
  v2s.map.exp.tag     = 'exp';
  v2s.map.exp.name    = 'Exponential';
  v2s.map.exp.strtype = 'r';
  v2s.map.exp.val     = {2};
  v2s.map.exp.num     = [1 1];
  v2s.map.exp.help    = {
    'The argument defines the distance in mm where values are decayed to 50% (recommended value is 2 mm).'
    ''
  };

  v2s.map.str         = cfg_entry;
  v2s.map.str.tag     = 'str';
  v2s.map.str.name    = 'Expression';
  v2s.map.str.strtype = 's';
  v2s.map.str.num     = [1 Inf];
  v2s.map.str.help    = {
    ''
  };

  v2s.mapping         = cfg_choice;
  v2s.mapping.tag     = 'mapping';
  v2s.mapping.name    = 'Mapping function';
  if expert
    v2s.mapping.values  = {
      v2s.map.mean ...
      v2s.map.median ...
      v2s.map.range ...
      v2s.map.min ...
      v2s.map.max ...
      v2s.map.exp ...
      v2s.map.str ...
      }; 
  else
    v2s.mapping.values  = {
      v2s.map.mean ...
      v2s.map.median ...
      v2s.map.range ...
      v2s.map.min ...
      v2s.map.max ...
      v2s.map.exp ...
      };
  end
  v2s.mapping.val     = {v2s.map.exp};
  v2s.mapping.help    = {
    'Volume extration interpolation type. '
    ' -average:  Use average for mapping along normals.'
    ' -range:    Count number of values in range for mapping along normals.'
    '            If any value is out of range values will be counted only until this point'
    '            Default value: 3.40282e+38 3.40282e+38'
    ' -max:      Use maximum value for mapping along normals (Default). '
    '            Optionally a 2nd volume can be defined to output its value at the maximum value of the 1st volume.'
    ' -min:      Use minimum value for mapping along normals. '
    '            Optionally a 2nd volume can be defined to output its value at the minimum value of the 1st volume.'
    ' -exp:      Use exponential average of values for mapping along normals.'
    '            The argument defines the distance in mm where values are decayed to 50% (recommended value is 10mm).'
    '            Default value: 3.40282e+38'
    '' 
  };
  

  % Sampling function
  %---------------------------------------------------------------------  

  v2s.sample.GM         = cfg_branch;
  v2s.sample.GM.tag     = 'GM';
  v2s.sample.GM.name    = 'GM Area';
  v2s.sample.GM.help    = {
    '' 
  };

  v2s.sample.WM         = cfg_branch;
  v2s.sample.WM.tag     = 'WM';
  v2s.sample.WM.name    = 'WM Area';
  v2s.sample.WM.help    = {
    '' 
  };

  v2s.sample.CSF         = cfg_branch;
  v2s.sample.CSF.tag     = 'CSF';
  v2s.sample.CSF.name    = 'CSF Area';
  v2s.sample.CSF.help    = {
    '' 
  };

  v2s.sample.rpos         = cfg_entry;
  v2s.sample.rpos.tag     = 'rpos';
  v2s.sample.rpos.name    = 'Relative Position';
  v2s.sample.rpos.strtype = 'r'; 
  v2s.sample.rpos.num     = [1 1];
  v2s.sample.rpos.val     = {0.5};
  v2s.sample.rpos.help    = {
    '' 
  };

  v2s.sample.exact         = cfg_entry;
  v2s.sample.exact.tag     = 'exact';
  v2s.sample.exact.name    = 'Exact Position';
  v2s.sample.exact.strtype = 'r'; 
  v2s.sample.exact.num     = [1 3];
  v2s.sample.exact.val{1}  = [-1 0.5 1];
  v2s.sample.exact.help    = {
    '' 
  };
  
  v2s.sampling         = cfg_choice;
  v2s.sampling.tag     = 'sampling';
  v2s.sampling.name    = 'Sampling function';
  v2s.sampling.values  = {
    v2s.sample.GM ...
    v2s.sample.WM ...
    v2s.sample.CSF ...
    v2s.sample.rpos ...
    v2s.sample.exact ...
    };
  v2s.sampling.val     = {v2s.sample.exact};
  v2s.sampling.help    = {
    '' 
  };

  v2s.interp         = cfg_menu;
  v2s.interp.tag     = 'interp';
  v2s.interp.name    = 'Interpolation Type';
  v2s.interp.labels  = {'nearest','linear','cubic'};
  v2s.interp.values  = {{'nearest_neighbour'},{'linear'},{'cubic'}};
  v2s.interp.val     = {{'nearest_neighbour'}};
  v2s.interp.help    = {
    'Volume extration interpolation type. '
    ' -linear:            Use linear interpolation.'
    ' -nearest_neighbour: Use nearest neighbour interpolation (Default).'
    ' -cubic:             Use cubic interpolation.'
    ''
  };

  

% extract volumetric data in individual space
%-----------------------------------------------------------------------  
  v2s.data_surf_sub_lh         = cfg_files;
  v2s.data_surf_sub_lh.tag     = 'data_mesh_lh';
  v2s.data_surf_sub_lh.name    = 'Left Individual Surfaces';
  v2s.data_surf_sub_lh.filter  = 'gifti';
  v2s.data_surf_sub_lh.ufilter = '^lh.central.*';
  v2s.data_surf_sub_lh.num     = [1 Inf];
  v2s.data_surf_sub_lh.help    = {
    'Select left subject surface files.'
    'Right side will processed automaticly.'
    };
 
  v2s.data_surf_sub_rh         = cfg_files;
  v2s.data_surf_sub_rh.tag     = 'data_mesh_rh';
  v2s.data_surf_sub_rh.name    = 'Right Individual Surfaces';
  v2s.data_surf_sub_rh.filter  = 'gifti';
  v2s.data_surf_sub_rh.ufilter = '^rh.central.*';
  v2s.data_surf_sub_rh.num     = [0 Inf];
  v2s.data_surf_sub_rh.help    = {
    'Select right subject surface files.'
    };
  
  v2s.data_sub         = cfg_files; 
  v2s.data_sub.tag     = 'data_vol';
  v2s.data_sub.name    = 'Volumes';
  v2s.data_sub.filter  = 'image';
  v2s.data_sub.ufilter = '^(?!wmr|wp|w0rp|wc).*'; % no normalized images
  v2s.data_sub.num     = [1 Inf];
  v2s.data_sub.help    = {
    'Select subject space volumes.'
  };

  v2s.vol2surf      = cfg_exbranch;
  v2s.vol2surf.tag  = 'vol2surf';
  v2s.vol2surf.name = 'Extract Volume Data by Individual Surfaces';
  if expert
    v2s.vol2surf.val = {
      v2s.data_sub ...
      v2s.data_surf_sub_lh ...
      ... v2s.data_surf_sub_rh ...
      v2s.datafieldname ...
      v2s.mapping ...
      v2s.sampling ...
      v2s.interp ...
      };
  else
    v2s.vol2surf.val = {
      v2s.data_sub ...
      v2s.data_surf_sub_lh ...
      ... v2s.data_surf_sub_rh ...
      v2s.datafieldname ...
      v2s.mapping ...
      };
  end
  v2s.vol2surf.prog = @vbm_surf_vol2surf;
  v2s.vol2surf.help = {
    'Extract volumetric data from individual space.'
    ''
  };



%% extract volumetric data in template space
%-----------------------------------------------------------------------  
  v2s.data_surf_avg_lh         = cfg_files; 
  v2s.data_surf_avg_lh.tag     = 'data_mesh_lh';
  v2s.data_surf_avg_lh.name    = 'Left Template Surface';
  v2s.data_surf_avg_lh.filter  = 'gifti';
  v2s.data_surf_avg_lh.ufilter = '^lh.*';
  v2s.data_surf_avg_lh.num     = [1 1];
  v2s.data_surf_avg_lh.val{1}  = {fullfile(spm('dir'),'toolbox','vbm12','templates_surfaces','lh.central.Template_T1_IXI555_MNI152.gii')};
  v2s.data_surf_avg_lh.dir     = fullfile(spm('dir'),'toolbox','vbm12');
  v2s.data_surf_avg_lh.help    = {
    'Select left template surface file. '
    'Right side will processed automaticly.'
    };
  
  v2s.data_surf_avg_rh         = cfg_files; 
  v2s.data_surf_avg_rh.tag     = 'data_mesh_rh';
  v2s.data_surf_avg_rh.name    = 'Left Template Surface';
  v2s.data_surf_avg_rh.filter  = 'gifti';
  v2s.data_surf_avg_rh.ufilter = '^rh.*';
  v2s.data_surf_avg_rh.num     = [0 1];
  v2s.data_surf_avg_lh.val{1}  = {fullfile(spm('dir'),'toolbox','vbm12','templates_surfaces','lh.central.Template_T1_IXI555_MNI152.gii')};  
  v2s.data_surf_avg_rh.dir     = fullfile(spm('dir'),'toolbox','vbm12');
  v2s.data_surf_avg_rh.help    = {
    'Select right template surface file.'
    };
  
  v2s.data_norm         = cfg_files; 
  v2s.data_norm.tag     = 'data_vol';
  v2s.data_norm.name    = 'Volumes';
  v2s.data_norm.filter  = 'image';
  v2s.data_norm.ufilter = '^(?=wm|wp|w0rp|wc).*'; % only normalized images
  v2s.data_norm.num     = [1 Inf];
  v2s.data_norm.help    = {
    'Select normalized space volumes.'
  };

  v2s.vol2tempsurf      = cfg_exbranch;
  v2s.vol2tempsurf.tag  = 'vol2surftemp';
  v2s.vol2tempsurf.name = 'Extract Volume Data by Template Surfaces';
  if expert
    v2s.vol2tempsurf.val  = {
      v2s.data_norm ...
      v2s.data_surf_avg_lh ...
      ... v2s.data_surf_avg_rh ...
      v2s.datafieldname ...
      v2s.mapping ...
      v2s.sampling ...
      v2s.interp ...
    };
  else
    v2s.vol2tempsurf.val  = {
      v2s.data_norm ...
      v2s.data_surf_avg_lh ...
      ... v2s.data_surf_avg_rh ...
      v2s.datafieldname ...
      v2s.mapping ...
    };
  end
  v2s.vol2tempsurf.prog = @vbm_surf_vol2surf;
  v2s.vol2tempsurf.help = {
    'Extract volumetric data from template space.'
    'The template surface was generated by VBM12 surface processing [1] of the average wmr*.nii images of VBM12.   '
    ''
    '  [1] Dahnke, R., Yotter, R. A., and Gaser, C. 2012.'
    '  Cortical thickness and central surface estimation.'
    '  Neuroimage, 65C:336?348.'
    ''
    '  WARNING: ONLY FOR VISUAL PURPOSE! '
    '           ALTHOUGH THERE IS A GOOD OVERLAPE TO THE TEMPLATE,'
    '           THERE IS ONLY A SMALL OVERLAPE TO THE INDIVIDUAL ANATOMY!'
    '           DO NOT USE THE RESULTS FOR FURTHER STATISTIC!'
    ''
  };




% surface calculations 
% ----------------------------------------------------------------------
% estimation per person (individual and group sampling):
% g groups with i datafiles and i result datafile
 
  sc.cdata         = cfg_files;
  sc.cdata.tag     = 'cdata';
  sc.cdata.name    = 'Surface Data Files';
  sc.cdata.filter  = 'any';
  sc.cdata.ufilter = '^s.mm.*';
  sc.cdata.num     = [1 Inf];
  sc.cdata.help    = {'These are the surface data files that are used by the calculator.  They are referred to as s1, s2, s3, etc in the order that they are specified.'};
  
  sc.cdata_sub         = cfg_files;
  sc.cdata_sub.tag     = 'cdata';
  sc.cdata_sub.name    = 'Surface Data Files';
  sc.cdata_sub.filter  = 'any';
  sc.cdata_sub.ufilter = '^(s.mm.[rl]h|[rl]h).(?!cent|sphe|defe).*';
  sc.cdata_sub.num     = [1 Inf];
  sc.cdata_sub.help    = {'These are the surface data files that are used by the calculator.  They are referred to as s1, s2, s3, etc in the order that they are specified.'};
   
  sc.cdata_sample         = cfg_repeat;
  sc.cdata_sample.tag     = 'cdata_sub.';
  sc.cdata_sample.name    = 'Surface Data Sample';
  sc.cdata_sample.values  = {sc.cdata_sub};
  sc.cdata_sample.num     = [1 Inf];
  sc.cdata_sample.help = {...
    'Specify data for each sample.  All samples must have the same size and same order.'};
 
  sc.outdir         = cfg_files;
  sc.outdir.tag     = 'outdir';
  sc.outdir.name    = 'Output Directory';
  sc.outdir.filter  = 'dir';
  sc.outdir.ufilter = '.*';
  sc.outdir.num     = [0 1];
  sc.outdir.val{1}  = {''};
  sc.outdir.help    = {
    'Files  produced by this  function will be written into this output directory.  If no directory is given, images will be written  to current working directory.  If both output filename and output directory contain a directory, then output filename takes precedence.'
  };
  
  sc.surfname         = cfg_entry;
  sc.surfname.tag     = 'dataname';
  sc.surfname.name    = 'Output Filename';
  sc.surfname.strtype = 's';
  sc.surfname.num     = [1 Inf];
  sc.surfname.val     = {'output'};
  sc.surfname.help    = {'The output surface data file is written to current working directory unless a valid full pathname is given.  If a path name is given here, the output directory setting will be ignored.'};
 
  sc.dataname         = cfg_entry;
  sc.dataname.tag     = 'dataname';
  sc.dataname.name    = 'Texture Name';
  sc.dataname.strtype = 's';
  sc.dataname.num     = [1 Inf];
  sc.dataname.val     = {'output'};
  sc.dataname.help    = {
    'Name of the surface data part of the filename.'
    ''
    '  [s*mm.][rh|lh].DATANAME[.resampled|].subjectname[.gii]' 
  };

  sc.expression         = cfg_entry;
  sc.expression.tag     = 'expression';
  sc.expression.name    = 'Expression';
  sc.expression.strtype = 's';
  sc.expression.num     = [1 Inf];
  sc.expression.val     = {' '};
  sc.expression.help    = {
    'Example expressions (f):'
    '  * Mean of six surface textures (select six texture files)'
    '    f = ''(s1+s2+s3+s4+s5+s6)/6'''
    '  * Make a binaray mask texture at threshold of 100'
    '    f = ''(s1>100)'''
    '  * Make a mask from one texture and apply to another'
    '    f = ''s2.*(s1>100)'''
    '        - here the first texture is used to make the mask, which is applied to the second texture'
    '  * Sum of n texures'
    '    f = ''i1 + i2 + i3 + i4 + i5 + ...'''
    '  * Sum of n texures (when reading data into a data-matrix - use dmtx arg)'
    '    f = mean(S)'
    ''
  };

  sc.dmtx         = cfg_menu;
  sc.dmtx.tag     = 'dmtx';
  sc.dmtx.name    = 'Data Matrix';
  sc.dmtx.labels  = {
    'No - don''t read images into data matrix',...
    'Yes -  read images into data matrix'
  };
  sc.dmtx.values  = {0,1};
  sc.dmtx.val     = {0};
  sc.dmtx.help    = {
    'If the dmtx flag is set, then textures are read into a data matrix S (rather than into separate variables s1, s2, s3,...). The data matrix  should be referred to as S, and contains textures in rows. Computation is vertex by vertex, S is a NxK matrix, where N is the number of input textures, and K is the number of vertices per plane.'
  };


% ----------------------------------------------------------------------

  surfcalc      = cfg_exbranch;
  surfcalc.tag  = 'surfcalc';
  surfcalc.name = 'Surface Calculator';
  surfcalc.val  = {
    sc.cdata ...
    sc.surfname ...
    sc.outdir ...
    sc.expression ...
    sc.dmtx ...
  };
  surfcalc.prog = @vbm_surf_calc;
  surfcalc.help = {
    'Mathematical operations for surface data (textures).'
    'It works similar to ''spm_imcalc''.  The Input textures must have the same number of entries.  This means that the must came from same hemisphere of a subject, or the have to be resampled.'
  };


  surfcalcsub      = cfg_exbranch;
  surfcalcsub.tag  = 'surfcalcsample';
  surfcalcsub.name = 'Surface Calculator (many subjects)';
  surfcalcsub.val  = {
    sc.cdata_sample ...
    sc.dataname ...
    sc.outdir ...
    sc.expression ...
    sc.dmtx ...
  };
  surfcalcsub.prog = @vbm_surf_calc;
  surfcalcsub.help = {
    'Mathematical operations for a set of surface data (textures).'
    'In contrast to the ''Texture Calculator'' it allows the definition of texture sets ''si'' for multiple subjects.  Therefore, each sample requires textures of the same subjects to evalute the expression for each subject.'
  };




%% Resample surfaces 
%-----------------------------------------------------------------------
  data_surf         = cfg_files;
  data_surf.tag     = 'data_surf';
  data_surf.name    = 'Surfaces Data';
  data_surf.filter  = 'any';
  data_surf.ufilter = '^[lr]h.[tgfl][hyro][irag][cias]';
  data_surf.num     = [1 Inf];
  data_surf.help    = {'Select Surfaces Data Files for Resampling to Template Space.'};

  fwhm         = cfg_entry;
  fwhm.tag     = 'fwhm';
  fwhm.name    = 'Smoothing Filter Size in FWHM';
  fwhm.strtype = 'r';
  fwhm.num     = [1 1];
  fwhm.val     = {15};
  fwhm.help    = {
    'Select filter size for smoothing. For cortical thickness a good starting value is 15mm, while other surface parameters based on cortex folding (e.g. gyrification, cortical complexity) need a larger filter size of about 25mm.'};
  
  surfresamp      = cfg_exbranch;
  surfresamp.tag  = 'surfresamp';
  surfresamp.name = 'Resample and Smooth Surface Data';
  surfresamp.val  = {data_surf,fwhm};
  surfresamp.prog = @vbm_surf_resamp;
  surfresamp.help = {
  'In order to analyze surface parameters all data have to be rsampled into template space and the rsampled data have to be finally smoothed. Resampling is done using the warped coordinates of the resp. sphere.'};




%% Resample surfaces FreeSurfer
%-----------------------------------------------------------------------
  data_fs         = cfg_files;
  data_fs.tag     = 'data_fs';
  data_fs.name    = 'Freesurfer Subject Directories';
  data_fs.filter  = 'dir';
  data_fs.ufilter = '.*';
  data_fs.num     = [1 Inf];
  data_fs.help    = {'Select subject folders of freesurfer data to rsample thickness data.'};

  outdir         = cfg_files;
  outdir.tag     = 'outdir';
  outdir.name    = 'Output Directory';
  outdir.filter  = 'dir';
  outdir.ufilter = '.*';
  outdir.num     = [0 1];
  outdir.help    = {'Select a directory where files are written.'};

  surfresamp_fs      = cfg_exbranch;
  surfresamp_fs.tag  = 'surfresamp_fs';
  surfresamp_fs.name = 'Resample and Smooth Existing FreeSurfer Thickness Data';
  surfresamp_fs.val  = {data_fs,fwhm,outdir};
  surfresamp_fs.prog = @vbm_surf_resamp_freesurfer;
  surfresamp_fs.help = {
  'If you have existing freesurfer thickness data this function can be used to resample these data, smooth the resampled data, and convert freesurfer data to gifti format.'};





%% Toolset
%-----------------------------------------------------------------------
  
  stools = cfg_choice;
  stools.name   = 'Surface Tools';
  stools.tag    = 'stools';
  stools.values = { ...
    check_mesh_cov, ...
    surfextract, ...
    surfresamp, ...
    surfresamp_fs,...
    v2s.vol2surf, ...
    v2s.vol2tempsurf, ...
    surfcalc, ...
    surfcalcsub ...
    };

return


%% Result files
%_______________________________________________________________________
