function cg_vbm_run_job(job,estwrite,tpm,subj)
    
    stime = clock;

    %% print current VBM release number and subject file
    A = ver; r = 0;
    for i=1:length(A)
        if strcmp(A(i).Name,'Voxel Based Morphometry Toolbox')
            r = str2double(A(i).Version);
        end
    end
    clear A 

    str  = sprintf('VBM12 r%d',r);
    str2 = spm_str_manip(job.channel(1).vols{subj},['a' num2str(70 - length(str))]);
    vbm_io_cprintf([0.2 0.2 0.8],'\n%s\n%s: %s%s\n%s\n',...
          repmat('-',1,72),str,...
          repmat(' ',1,70 - length(str) - length(str2)),str2,...
          repmat('-',1,72));
    clear r str str2


    %  -----------------------------------------------------------------
    %  check resolution properties
    %  -----------------------------------------------------------------
    %  There were some images that should not be processed. So we have  
    %  to check for high slice thickness, low resolution.
    %  -----------------------------------------------------------------
    for n=1:numel(job.channel) 
      V = spm_vol(job.channel(n).vols{subj});
      vx_vol = sqrt(sum(V.mat(1:3,1:3).^2));

      if any(vx_vol>5)  % to high slice thickness
        error('VBM:cg_vbm_write:ToLowResolution', sprintf(...
             ['Voxel resolution has to be better than 3.5 mm in any dimention \n' ...
              'for save VBM preprocessing and a reasonable anatomical analysis! \n' ...
              'This image has got a resolution %0.2fx%0.2fx%0.2f mm%s. '], ... 
                vx_vol,char(179))); %#ok<SPERR>
      end
      if prod(vx_vol)>27  % to low voxel volume (smaller than 3x3x3 mm3)
        error('VBM:cg_vbm_write:ToHighVoxelVolume', ...
             ['Voxel volume has to be smaller than 10 mm%s (around 2x2x2 mm%s) to \n' ...
              'allow a save VBM preprocessing and reasonable anatomical analysis! \n' ...
              'This image has got a voxel volume of %0.2f mm%s. '], ...
              char(179),char(179),prod(vx_vol),char(179));
      end
      if max(vx_vol)/min(vx_vol)>8 % isotropy 
        error('VBM:cg_vbm_write:ToStrongIsotropy', sprintf(...
             ['Voxel isotropy (max(vx_size)/min(vx_size)) has to be smaller 8 to \n' ...
              'allow a save VBM preprocessing and reasonable anatomical analysis! \n' ...
              'This image has got a resolution %0.2fx%0.2fx%0.2f mm%s and a isotropy of %0.2f. '], ...
              vx_vol,char(179),max(vx_vol)/min(vx_vol))); %#ok<SPERR>
      end
    end


    % save original file name 
    for n=1:numel(job.channel) 
      job.channel(n).vols0{subj} = job.channel(n).vols{subj};
    end
    % noise-correction
    if job.vbm.sanlm && job.extopts.NCstr

        switch job.vbm.sanlm
          case {1,2,3,4}, stime = vbm_io_cmd('NLM-filter with multi-threading');
          case {5},   stime = vbm_io_cmd('Temporary NLM-filter with multi-threading');
        end


        for n=1:numel(job.channel) 
            V = spm_vol(job.channel(n).vols{subj});
            Y = single(spm_read_vols(V));
            Y(isnan(Y)) = 0;
            switch job.vbm.sanlm
              case {1,2,3,4,5},   sanlmMex(Y,3,1,0);          % use multi-threaded version
            end
            Vn = vbm_io_writenii(V,Y,'n','noise corrected','float32',[0,1],[1 0 0]);
            job.channel(n).vols{subj} = Vn.fname;
            clear Y V Vn;
        end

        fprintf('%4.0fs\n',etime(clock,stime));     
    else
       if ~strcmp(job.vbm.species,'human')
         % this is necessary because of the real masking of the T1 data 
         % for spm_preproc8 that include rewriting the pricture!
         for n=1:numel(job.channel) 
          [pp,ff] = spm_fileparts(job.channel(n).vols{subj}); 
          job.channel(n).vols{subj} = fullfile(pp,['n' ff '.nii']);
         end
       end
    end
   
      
    
    %% Interpolation
    % The interpolation can help to reduce problems for morphological
    % operations for low resolutions and strong isotropic images. 
    % Especially for Dartel a native resolution higher than the Dartel 
    % resolution helps to reduce normalization artifacts of the
    % deformation. Also this artifacts were reduce by the final smoothing
    % it is much better to avoid them.  
    Vt      = tpm.V(1); 
    vx_vold = min(cg_vbm_get_defaults('extopts.vox'),sqrt(sum(Vt.mat(1:3,1:3).^2))); clear Vt; % Dartel resolution 
    for n=1:numel(job.channel) 

      % prepare header of resampled volume
      Vi        = spm_vol(job.channel(n).vols{subj}); 
      vx_vol    = sqrt(sum(Vi.mat(1:3,1:3).^2));
      switch job.vbm.restype 
        case 'native'
          vx_voli  = vx_vol;
        case 'fixed', 
          vx_voli  = min(vx_vol ,job.vbm.resval(1) ./ ((vx_vol > (job.vbm.resval(1)+job.vbm.resval(2)))+eps));
          vx_voli  = max(vx_voli,job.vbm.resval(1) .* (vx_vol < (job.vbm.resval(1)-job.vbm.resval(2))));
        case 'best'
          vx_voli  = min(vx_vol ,job.vbm.resval(1) ./ ((vx_vol > (job.vbm.resval(1)+job.vbm.resval(2)))+eps));
        otherwise 
          error('cg_vbm_run_job:restype','Unknown resolution type ''%s''. Choose between ''fixed'',''native'', and ''best''.',restype)
      end
      vx_voli = min(vx_vold,vx_voli); % guarantee Dartel resolution
      
      
      % interpolation 
      if any( (vx_vol ~= vx_voli) )  
       
        stime = vbm_io_cmd(sprintf('Internal resampling (%4.2fx%4.2fx%4.2fmm > %4.2fx%4.2fx%4.2fmm)',vx_vol,vx_voli));
       
        Vi        = rmfield(Vi,'private'); 
        imat      = spm_imatrix(Vi.mat); 
        Vi.dim    = round(Vi.dim .* vx_vol./vx_voli);
        imat(7:9) = vx_voli .* sign(imat(7:9));
        Vi.mat    = spm_matrix(imat);

        Vn = spm_vol(job.channel(n).vols{subj}); 
        Vn = rmfield(Vn,'private'); 
        if ~(job.vbm.sanlm && job.extopts.NCstr)
          % if no noise correction we have to add the 'n' prefix here
          [pp,ff,ee] = spm_fileparts(Vn.fname);
          Vi.fname = fullfile(pp,['n' ff ee]);
          job.channel(n).vols{subj} = Vi.fname;
        end
        if job.vbm.sanlm==0
          [pp,ff,ee,dd] = spm_fileparts(Vn.fname); 
          Vi.fname = fullfile(pp,['n' ff ee dd]);
          job.channel(n).vols{subj} = Vi.fname;
        end
        vbm_vol_imcalc(Vn,Vi,'i1',struct('interp',6,'verb',0));

        fprintf('%4.0fs\n',etime(clock,stime));    
      end
      clear Vi Vn;
    end
    
    
    %%
    if estwrite % estimate and write segmentations            

        % 
        images = job.channel(1).vols{subj};
        for n=2:numel(job.channel)
            images = char(images,job.channel(n).vols{subj});
        end

        obj.image    = spm_vol(images);
        spm_check_orientations(obj.image);

        obj.fwhm     = job.vbm.fwhm;
        obj.fudge    = 5;
        obj.biasreg  = cat(1,job.biasreg);
        obj.biasfwhm = cat(1,job.biasfwhm);
        obj.tpm      = tpm;
        obj.lkp      = [];
        if all(isfinite(cat(1,job.tissue.ngaus))),
            for k=1:numel(job.tissue),
                obj.lkp = [obj.lkp ones(1,job.tissue(k).ngaus)*k];
            end;
        end
        obj.reg      = job.vbm.reg;
        obj.samp     = job.vbm.samp;              
       


        %% Initial affine registration.
        
        % APP option with subparameter
        APP = cg_vbm_get_defaults('extopts.APP'); 
        if ~strcmp(job.vbm.species,'human'), APP=2; end
        switch APP
          case 0 % no APP
            doskullstripping = 0;
            dobiascorrection = 0;
            doregistration   = 0;
          case 1 % APP with affine registration
            doskullstripping = 1;
            dobiascorrection = 1;
            doregistration   = 1;
          case 2 % APP without affine registration
            doskullstripping = 1;
            dobiascorrection = 1;
            doregistration   = 0;
        end
        if APP>0
          stime = vbm_io_cmd(sprintf('Affine registration (APP=%d)',APP)); 
        else
          stime = vbm_io_cmd('Affine registration'); 
        end
        
        Affine  = eye(4);
        [pp,ff] = spm_fileparts(job.channel(1).vols{subj});
        Pbt = fullfile(pp,['brainmask_' ff '.nii']);
        Pb  = char(cg_vbm_get_defaults('extopts.brainmask'));
        Pt1 = char(cg_vbm_get_defaults('extopts.T1'));
        if ~isempty(job.vbm.affreg)
          %%
          warning off %#ok<WNOFF>
          try 
            VG = spm_vol(Pt1);
          catch
            pause(rand(1))
            VG = spm_vol(Pt1);
          end
          VF = spm_vol(obj.image(1));

           % Rescale images so that globals are better conditioned
          VF.pinfo(1:2,:) = VF.pinfo(1:2,:)/spm_global(VF);
          VG.pinfo(1:2,:) = VG.pinfo(1:2,:)/spm_global(VG);

          % smooth data
          if APP>0
            resa = obj.samp*3; % definine smoothing by sample size
            
            %% rough bias correction (~4 seconds for 1 mm3): 
            %  All thissues (low gradient) should have a similar intensity.
            %    ds('l2','',0.5,Yo/WMth,Yg<0.2,Yo/WMth,Ym,80)
            Ysrc = single(obj.image.private.dat(:,:,:)); 
            Yg   = vbm_vol_grad(Ysrc,vx_vol)./max(eps,Ysrc);
            WMth = single(vbm_stat_nanmedian(Ysrc(Yg(:)<0.2 & Ysrc(:)>vbm_stat_nanmean( ...
              Ysrc(Yg(:)<0.2 & Ysrc(:)>vbm_stat_nanmean(Ysrc(:))))))); 
            Ygs  = smooth3(Yg);
            Ydiv = vbm_vol_div(Ysrc/WMth,vx_vol);
            BGth = hist(Ysrc(Ygs(:)<0.1 & Ysrc(:)<WMth*0.5)/WMth,-1.0:0.05:1);
            BGth = find(cumsum(BGth)/sum(BGth)>0.05,1,'first')/20 - 1.0;
            BGth = min(BGth*WMth*2,WMth*0.2);
            %%  WI contain the values for correction for the object and
            %  an approximation is required for all other voxels.
            Yt   = Ysrc>BGth & Ysrc<WMth*1.1 & Yg<0.3 & Ydiv<0.2 & Ydiv>-1; 
            WI   = (Ysrc .* Yt) ./ max(eps,Yt);  
            [WI,resT2] = vbm_vol_resize(WI,'reduceV',vx_vol,vbm_stat_nanmean(vx_vol)*4,32,'max'); 
            WI   = vbm_vol_approx(WI,4,vx_vol);
            WI   = vbm_vol_smooth3X(WI,4);
            WI   = vbm_vol_resize(WI,'dereduceV',resT2);      
            %  A strong smoothing of this approximation is essential!
            WI   = vbm_vol_smooth3X(WI,2); 
            %%  Final intensity scaling
            Ym   = Ysrc ./ WI; 
            Wth  = single(vbm_stat_nanmedian(Ym(Yg(:)<0.2 & Ym(:)>vbm_stat_nanmean( Ym(Yg(:)<0.2 & Ym(:)>vbm_stat_nanmean(Ym(:))))))); 
            [WIth,WMv] = hist(Ym(Ygs(:)<0.1 & Ym(:)>Wth*0.5 & Ym(:)<Wth*1.5),0:0.01:2);
            [BIth,BGv] = hist(Ym(Ygs(:)<0.1 & Ym(:)<Wth*0.5),-1.0:0.01:1);
            BIth = find(cumsum(BIth)/sum(BIth)>0.05,1,'first'); BIth = BGv(BIth);
            WIth = find(cumsum(WIth)/sum(WIth)>0.95,1,'first'); WIth = WMv(WIth);  
            Ym   = (Ym - BIth) / (WIth-BIth); 
            
            %% write data to VF
            VF.dt         = [spm_type('UINT8') spm_platform('bigend')];
            VF.dat(:,:,:) = uint8(Ym * 200); 
            VF.pinfo      = repmat([1;0],1,size(Ym,3));
            clear WI; 
            
            % smoothing
            VF1  = spm_smoothto8bit(VF,resa);
            VG1  = spm_smoothto8bit(VG,resa);
          else  % old approach
            resa = 8;
            VF1  = spm_smoothto8bit(VF,resa);
            VG1  = VG; 
          end        

          aflags     = struct('sep',resa,'regtype',job.vbm.affreg,'WG',[],'WF',[],'globnorm',0);
          aflags.sep = max(aflags.sep,max(sqrt(sum(VG(1).mat(1:3,1:3).^2))));
          aflags.sep = max(aflags.sep,max(sqrt(sum(VF(1).mat(1:3,1:3).^2))));

          try
            spm_plot_convergence('Init','Coarse Affine Registration','Mean squared difference','Iteration');
          catch
            spm_chi2_plot('Init','Coarse Affine Registration','Mean squared difference','Iteration');
          end
          [Affine0, scale]  = spm_affreg(VG1, VF1, aflags, eye(4)); Affine = Affine0; 

          
          %% improve sampling rate and use less smoothing and by brain masking
          try 
            aflags.WG  = spm_vol(Pb);
          catch
            pause(rand(1))
            aflags.WG  = spm_vol(Pb);
          end
          aflags.sep = aflags.sep/2;
          
          % old approach ... only smoothing of the VF with 8 mm
          if APP>0
            % apply first affine registration
            VFa = VF; 
            if doregistration, VFa.mat = Affine0 * VF.mat; else Affine = eye(4); end
            
            if isfield(VFa,'dat'), VFa = rmfield(VFa,'dat'); end
            [Vmsk,Yb] = vbm_vol_imcalc([VFa,spm_vol(Pb)],Pbt,'i2',struct('interp',3,'verb',0)); Yb = Yb>0.5; 
         
            % greater mask
            [dilmsk,resT2] = vbm_vol_resize(single(Yb),'reduceV',vx_vol,mean(vx_vol)*4,32); 
            dilmsk  = vbdist(dilmsk,true(size(dilmsk)),resT2.vx_volr);
            dilmsk  = vbm_vol_resize(smooth3(dilmsk),'dereduceV',resT2); 
            
            Hth  = vbm_stat_nanmean(Ym(Ym(:)>0.2 & Ym(:)<1.2  & Ygs(:)<0.2 & ~Yb(:) & Ydiv(:)<0.05 & Ydiv(:)>-0.5)); % average intensity of major head tissues
            GMth = vbm_stat_nanmean(Ym(Ym(:)>0.4 & Ym(:)<0.9  & Ygs(:)<0.2 & ~Yb(:) & Ydiv(:)<0.1 & Ydiv(:)>-0.1));  % first guess of the GM intensity
            CMth = vbm_stat_nanmean(Ym(Ym(:)>0.1 & Ym(:)<GMth*0.7 & Ygs(:)<0.2 & ~Yb(:) & Ydiv(:)>-0.05));  % first guess of the CSF intensity
           
            % rough scull stripping
            %  The affine registration, especially spm_preproc8 requires a very good masking!
            %  Because we it is also required for the Unified Segmenation
            %  a wider mask with a complete brain is important
            %    ds('l2','m',0.5,Ym*0.7+0.3,Yb,Ysrc/WMth,Ym,80)
            Yb = (dilmsk<10 & Ym<1.2) & (Ym>0.7) & (Yg.*Ym)<0.3; Yb(smooth3(Yb)<0.5)=0; 
            Yb = single(vbm_vol_morph(Yb,'lo'));
            [dilmsk2,resT2] = vbm_vol_resize(single(Yb),'reduceV',vx_vol,mean(vx_vol)*4,32); 
            dilmsk2  = vbdist(dilmsk2,true(size(dilmsk)),resT2.vx_volr);
            dilmsk2  = vbm_vol_resize(smooth3(dilmsk2),'dereduceV',resT2); 
            %  WM growing
            Yb(Yb<0.5 & (dilmsk2>20 | Ym>1.1 | Ym<GMth | (Yg.*Ym)>0.5))=nan;
            [Yb1,YD] = vbm_vol_downcut(Yb,Ym,0.01); 
            Yb(isnan(Yb))=0; Yb((YD.*dilmsk2/10)<400/mean(vx_vol))=1; Yb(isnan(Yb))=0;
            Yb = smooth3(Yb)>0.5; 
            Yb = single(Yb | (Ym>0.3 & Ym<1.2 & vbm_vol_morph(Yb,'lc',4)));
            % GM growing
            Yb(Yb<0.5 & (dilmsk2>30 | Ym>1.1 | Ym<CMth | (Yg.*Ym)>0.5))=nan;
            [Yb1,YD] = vbm_vol_downcut(Yb,Ym,0.00);
            Yb(isnan(Yb))=0; Yb((YD.*dilmsk2/10)<400/mean(vx_vol))=1; Yb(isnan(Yb))=0; clear Yb1 YD; 
            Yb(smooth3(Yb)<0.5)=0;
            Yb = single(Yb | (Ym>0.1 & Ym<1.1 & vbm_vol_morph(Yb,'lc',4)));
            % CSF growing (add some tissue around the brain)
            Yb(Yb<0.5 & (dilmsk2>30 | Ym<0.1 | Ym>1.1 | (Yg.*Ym)>0.5))=nan;
            [Yb1,YD] = vbm_vol_downcut(Yb,Ym,-0.01); Yb(isnan(Yb))=0; 
            Yb(YD<400/mean(vx_vol))=1; Yb(isnan(Yb))=0; clear Yb1 YD; 
            Yb(smooth3(Yb)<0.7)=0;
            Yb = single(vbm_vol_morph(Yb,'lab'));
            Yb = Yb | (Ym>0.1 & Ym<1.2 & vbm_vol_morph(Yb,'lc',8));
            % wider mask???
            %Yb = Yb | (Ym<0.6 & vbm_vol_morph(Yb,'d',2));
            Yb = vbm_vol_smooth3X(Yb,2)>0.3;
            Ymo=Ym; 
            %% improve bias correction
            Ym   = Ymo;
            Yw   = Ym>mean([1.0,GMth])  & Ym<1.2               & Ygs<0.5 & Yb & Ydiv<0.05 & Ydiv>-0.5; 
            Yg   = Ym>mean([CMth,GMth]) & Ym<mean([1,GMth])    & Ygs<0.1 & Yb & Ydiv<0.10 & Ydiv>-0.1;  
            Yc   = Ym<mean([CMth,GMth]) & Yg<0.1 & vbm_vol_smooth3X(Yb,8)>0.95;
            Yh   = vbm_vol_morph(Ym>max(CMth,Hth*0.3) & Ym<1 & Ygs<0.2 & vbm_vol_smooth3X(Yb,8)<0.05 & Ydiv<0.2 & Ydiv>-0.2,'o');
            WI   = max( cat(4,(Ysrc .* Yw ./ max(eps,Yw) ), ... 
                   (Ysrc/(median(Ysrc(Yg(:)))/median(Ysrc(Yw(:)))) .* Yg ./ max(eps,Yg) ), ... 
                   (Ysrc/(median(Ysrc(Yc(:)))/median(Ysrc(Yw(:)))) .* Yc ./ max(eps,Yc) ), ... 
                   (Ysrc/Hth .* Yh ./ max(eps,Yh) ) ) , [], 4); 
            [WI,resT2] = vbm_vol_resize(WI,'reduceV',vx_vol,mean(vx_vol)*2,32,'meanm'); 
            WI   = vbm_vol_approx(WI,2,resT2.vx_volr);
            WI   = vbm_vol_smooth3X(WI,4); 
            WI   = vbm_vol_resize(WI,'dereduceV',resT2);
            WI   = vbm_vol_smooth3X(WI,2); 
            %  Final intensity scaling
            Ym  = Ysrc ./ WI; 
            Wth  = single(vbm_stat_nanmedian(Ym(Ygs(:)<0.2 & Yb(:) & Ymo(:)>0.9))); 
            [WIth,WMv] = hist(Ym(Ygs(:)<0.1 &  Yb(:) & Ym(:)>GMth & Ym(:)<Wth*1.2),0:0.01:2);
            [BGth,BGv] = hist(Ym(Ygs(:)<0.1 & ~Yb(:) & Ym(:)<Wth*0.5),-1.0:0.01:1);
            BGth = find(cumsum(BGth)/sum(BGth)>0.05,1,'first'); BGth = BGv(BGth);
            WIth = find(cumsum(WIth)/sum(WIth)>0.90,1,'first'); WIth = WMv(WIth);  
            Ym   = (Ym - BGth) / (WIth-BGth); 
            
            
            %% msk T1 & TPM
            VF.dat(:,:,:) =  vbm_vol_ctype(Ym*200 .* Yb); 
            VF1 = spm_smoothto8bit(VF,aflags.sep/2);
            
            VG1 = spm_smoothto8bit(VG,0.1);
            VG1.dat = VG1.dat .* uint8(spm_read_vols(spm_vol(Pb))>0.5); 
            VG1 = spm_smoothto8bit(VG1,aflags.sep/2);
            
          else
            VF1 = spm_smoothto8bit(VF,aflags.sep/2);
            VG1 = VG; 
          end
       
          try
            spm_plot_convergence('Init','Coarse Affine Registration 2','Mean squared difference','Iteration');
          catch
            spm_chi2_plot('Init','Coarse Affine Registration 2','Mean squared difference','Iteration');
          end
          Affine1 = spm_affreg(VG1, VF1, aflags, Affine, scale);   
          if ~any(isnan(Affine1(1:3,:))), Affine = Affine1; end
            
          clear VG1 VF1

        end
        
        
        % Fine Affine Registration with 3 mm sampling distance
        % This does not work for non human (or very small brains)
        if APP==0
          spm_plot_convergence('Init','Fine Affine Registration','Mean squared difference','Iteration');
          Affine3 = spm_maff8(obj.image(1),obj.samp,obj.fudge,obj.tpm,Affine,job.vbm.affreg);
          if ~any(isnan(Affine3(1:3,:))), Affine = Affine3; end
        end
        warning on  %#ok<WNON>
        obj.Affine = Affine;
        fprintf('%4.0fs\n',etime(clock,stime));   
        
        
        
        %% SPM preprocessing 1
        % ds('l2','a',0.5,Ysrc/WMth,Yb,Ysrc/WMth,Yb,140);
        if APP>0
          stime = vbm_io_cmd(sprintf('SPM preprocessing 1 (APP=%d)',APP));
            
          obj.msk = spm_smoothto8bit(VF,0.1); obj.msk.dat = uint8(Yb*255); 
          obj.image.dt         = [spm_type('FLOAT32') spm_platform('bigend')];
          if dobiascorrection
            th = vbm_stat_nanmean(Ysrc(Yb(:) & Ysrc(:)>vbm_stat_nanmean(Ysrc(Yb(:))))) / ...
                 vbm_stat_nanmean(Ym(Yb(:)   & Ym(:)>vbm_stat_nanmean(Ym(Yb(:)))));
            obj.image.private.dat(:,:,:) = single(min(2*WMth,Ym * th)); % rewrite image
            obj.image.dat(:,:,:) = single(min(2*WMth,Ym * th .* Yb)); 
          else
            obj.image.dat(:,:,:) = single(min(2*WMth,Ysrc .* Yb)); 
          end
          obj.image.pinfo      = repmat([1;0],1,size(Ysrc,3));
        else
          stime = vbm_io_cmd('SPM preprocessing 1');
        end
        warning off %#ok<WNOFF>
        try 
          res = spm_preproc8(obj);
        catch
          if (job.vbm.sanlm && job.extopts.NCstr) || any( (vx_vol ~= vx_voli) ) || ~strcmp(job.vbm.species,'human') 
            [pp,ff,ee] = spm_fileparts(job.channel(1).vols{subj});
            delete(fullfile(pp,[ff,ee]));
          end
          error('VBM:cg_vbm_run_job:spm_preproc8','Error in spm_preproc8. Check image and orientation. \n');
        end
        warning on  %#ok<WNON>
        
        if cg_vbm_get_defaults('extopts.debug')==2
          % save information for debuging and OS test
          [pth,nam] = spm_fileparts(job.channel(1).vols0{subj}); 
          tmpmat = fullfile(pth,sprintf('%s_%s_%s.mat',nam,'runjob','postpreproc8')); 
          save(tmpmat,'obj','res','Affine','Affine0','Affine1','Affine3');      
        end 
        
        fprintf('%4.0fs\n',etime(clock,stime));   
    end
    
    %% check contrast
    Tgw = [mean(res.mn(res.lkp==1)) mean(res.mn(res.lkp==2))]; 
    Tth = [
      max( min(mean(res.mn(res.lkp==3)) , max(Tgw)+abs(diff(Tgw))),min(Tgw)-abs(diff(Tgw)) ) ... % csf with limit for T2!
      mean(res.mn(res.lkp==1)) ... gm
      mean(res.mn(res.lkp==2)) ... wm 
    ];
    
    % inactive preprocessing of inverse images (PD/T2) 
    if cg_vbm_get_defaults('extopts.INV')==0 && any(diff(Tth)<=0)
      error('VBM:cg_vbm_write:BadImageProperties', ...
      ['VBM12 is designed to work only on highres T1 images.\n' ...
       'T2/PD preprocessing can be forced on your own risk by setting \n' ...
       '''vbm.extopts.INV=1'' in the vbm default file. If this was a highres \n' ...
       'T1 image than the initial segmentation seemed to be corrupded, maybe \n' ...
       'by alignment problems (check image orientation).']);    
    end
            
    %% Final iteration, so write out the required data.
    tc = [cat(1,job.tissue(:).native) cat(1,job.tissue(:).warped)];
    bf = job.bias;
    df = job.vbm.write;
    lb = job.label;
    jc = job.jacobian;
    res.stime = stime;
    res.image0 = spm_vol(job.channel(1).vols0{subj}); 
    cg_vbm_write(res, tc, bf, df, lb, jc, job.vbm, obj.tpm, job);
    
    % delete denoised/interpolated image
    if (job.vbm.sanlm && job.extopts.NCstr) || any( (vx_vol ~= vx_voli) ) || ~strcmp(job.vbm.species,'human') 
      [pp,ff,ee] = spm_fileparts(job.channel(1).vols{subj});
      delete(fullfile(pp,[ff,ee]));
    end
%%
return
%=======================================================================
function Yg = vbm_vol_grad(Ym,vx_vol)
% ----------------------------------------------------------------------
% gradient map for edge description
% ----------------------------------------------------------------------
  [gx,gy,gz] = vbm_vol_gradient3(Ym); 
  Yg = abs(gx./vx_vol(1))+abs(gy./vx_vol(2))+abs(gz./vx_vol(3)); 
  %Yg = Yg ./ (Ym+eps);
return
%=======================================================================

%=======================================================================
function Ydiv = vbm_vol_div(Ym,vx_vol)
% ----------------------------------------------------------------------
% Divergence helps to identify all gyri that should not be in the GM, but 
% helps to improve the WM. Divergence estimation is very memory intensive 
% so it is better to limit the resolution.
% ----------------------------------------------------------------------
  [Ymr,resT2] = vbm_vol_resize(Ym,'reduceV',vx_vol,1.5,32);
  [gx,gy,gz]  = vbm_vol_gradient3(max(1/3,Ymr)); 
  Ydivr = smooth3(divergence(gy./vx_vol(1),gx./vx_vol(1),gz./vx_vol(3))); clear gx gy gz Ymr;
  Ydiv  = vbm_vol_resize(Ydivr,'dereduceV',resT2); 
return
%=======================================================================
