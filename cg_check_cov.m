function cg_check_cov(vargin)
%cg_check_cov to check covriance across sample
%
% Images have to be in the same orientation with same voxel size
% and dimension (e.g. normalized images)
% An output image will be save with SD at each voxel.
%_______________________________________________________________________
% Christian Gaser
% $Id$

global fname jY h1 h2 YpY slice_array
rev = '$Rev$';

if nargin == 1
  P = char(vargin.data);
  norm = vargin.scale;
  if isempty(vargin.nuisance)
    nuisance = [];
  else
    nuisance = vargin.nuisance.c;
  end
  slice_mm = vargin.slice;
  gap = vargin.gap;
end

if nargin < 1
  P = spm_select(Inf,'image','Select images');
end

V = spm_vol(deblank(P));
n = size(P,1);

if length(V)>1 & any(any(diff(cat(1,V.dim),1,1),1))
  error('images don''t all have same dimensions')
end
if max(max(max(abs(diff(cat(3,V.mat),1,3))))) > 1e-8
  error('images don''t all have same orientation & voxel size')
end

if nargin < 1
  norm = spm_input('Prop. scaling (e.g. for T1- or modulated images)?',1,'yes|no',[1 0],2);
  def_nuis = spm_input('Variable to covariate out (nuisance parameter)?','+1','yes|no',[1 0],2);
  if def_nuis
    nuisance = spm_input('Nuisance parameter:','+1','r',[],n);
  else
    nuisance = [];
  end
  slice_mm = spm_input('Slice [mm]?','+1','e',0,1);
  gap = spm_input('Gap for slices to speed up','+1','e',0,1);
end

if ~isempty(nuisance)
  if size(nuisance,2) ~= n
    nuisance = nuisance';
  end
end

% voxelsize and origin
vx =  sqrt(sum(V(1).mat(1:3,1:3).^2));
Orig = V(1).mat\[0 0 0 1]';

% range
range = ([1 V(1).dim(3)] - Orig(3))*vx(3);

% calculate slice from mm to voxel
sl = round(slice_mm/vx(3)+Orig(3));
while (sl < 1) | (sl > V(1).dim(3))
  slice_mm = spm_input(['Slice (in mm) [' num2str(range(1)) '...' num2str(range(2)) ']'],1,'e',0);
  sl = round(slice_mm/vx(3)+Orig(3));
end

% global scaling
if norm
  gm=zeros(size(V,1),1);
  disp('Calculating globals...');
  for i=1:size(V,1), gm(i) = spm_global(V(i)); end
  gm_all = mean(gm);
  for i=1:n
    V(i).pinfo(1:2,:) = gm_all*V(i).pinfo(1:2,:)/gm(i);
  end
end

%-Start progress plot
%-----------------------------------------------------------------------
vol = zeros(prod(V(1).dim(1:2)), n);
YpY = zeros(n);

spm_progress_bar('Init',V(1).dim(3),'Check covariance','planes completed')
slice_array = zeros([V(1).dim(1:2) n]);

% consider gap for slices to speed up the process
slices = 1:gap:V(1).dim(3);
[mn, ind] = min(abs(slices-sl));
slices = slices - slices(ind) + sl;
if slices(1) < 1
  slices = slices(2:end);
end
if slices(end) > V(1).dim(3)
  slices = slices(1:end-1);
end
if slices(end) < V(1).dim(3) - gap
  slices = [slices slices(end)+gap]; 
end

for j=slices

  M  = spm_matrix([0 0 j]);

  for i = 1:n
    img = spm_slice_vol(V(i),M,V(1).dim(1:2),[1 0]);
    vol(:,i) = img(:);
  end

  % get slice data
  if j == sl
    slice_array = reshape(vol,[V(1).dim(1:2) n]);
  end

  mean_slice = mean(reshape(vol,[V(i).dim(1:2) n]),3);
  mask = find(mean_slice ~= 0 & ~isnan(mean_slice));
  % remove nuisance and calculate again mean
  if ~isempty(nuisance) 
    vol(mask,:) = vol(mask,:) - vol(mask,:)*pinv(nuisance)*nuisance;
  end

  if ~isempty(mask)
    % make sure data is zero mean
    tmp_vol = vol(mask,:);
    tmp_vol = tmp_vol - repmat(mean(tmp_vol,1), [length(mask) 1]);
    YpY = YpY + (tmp_vol'*tmp_vol)/n;
  end 
  spm_progress_bar('Set',j);  
end

spm_progress_bar('Clear');

% normalize YpY
d = sqrt(diag(YpY)); % sqrt first to avoid under/overflow
dd = d*d';
YpY = YpY./(dd+eps);
t = find(abs(YpY) > 1); 
YpY(t) = YpY(t)./abs(YpY(t));
YpY(1:n+1:end) = sign(diag(YpY));

YpYsum = sum(YpY,1);
[iY, jY] = sort(YpYsum, 2, 'descend');
YpYsorted = YpY(jY,jY);
Nsorted = P(jY,:);

% extract mean covariance
mean_cov = zeros(n,1);
for i=1:n
  % extract row for each subject
  cov0 = YpY(i,:);
  % remove cov with its own
  cov0(i) = [];
  mean_cov(i) = mean(cov0);
end

threshold_cov = mean(mean_cov) - 2*std(mean_cov);

fprintf('Mean covariance: %3.2f\n',mean(mean_cov));

[tmp fname] = spm_str_manip(char(V.fname),'C');
fprintf('Compressed filenames: %s  \n',tmp);

% print suspecious files with cov>0.9
YpY_tmp = YpY - tril(YpY);
[indx, indy] = find(YpY_tmp>0.9);
if ~isempty(indx) & (sqrt(length(indx)) < 0.5*n)
  fprintf('\nUnusual large covariances (check that subjects are not identical):\n');
  for i=1:length(indx)
    % exclude diagonal
    if indx(i) ~= indy(i)
      % report file with lower mean covariance first
      if mean_cov(indx(i)) < mean_cov(indy(i))
        fprintf('%s and %s: %3.3f\n',fname.m{indx(i)},fname.m{indy(i)},YpY(indx(i),indy(i)));
      else
        fprintf('%s and %s: %3.3f\n',fname.m{indy(i)},fname.m{indx(i)},YpY(indy(i),indx(i)));
      end
    end
  end
end

% sort files
fprintf('\nMean covariance for data below 2 standard deviations:\n');
[mean_cov_sorted, ind] = sort(mean_cov,'descend');
n_thresholded = min(find(mean_cov_sorted < threshold_cov));

for i=n_thresholded:n
  fprintf('%s: %3.3f\n',V(ind(i)).fname,mean_cov_sorted(i));
end

Fgraph = spm_figure('GetWin','Graphics');
spm_figure('Clear',Fgraph);
FS    = spm('FontSizes');

xpos = 2*(0:n-1)/(n-1);
for i=1:n
  text(xpos(i),mean_cov(i),fname.m{i},'FontSize',FS(8),'HorizontalAlignment','center')
end

hold on
cg_boxplot({mean_cov});
set(gca,'XTick',[],'XLim',[-.25 2.25]);
if max(mean_cov) > min(mean_cov)
  set(gca,'YLim',[0.9*min(mean_cov) 1.1*max(mean_cov)]);
end
title(sprintf('Boxplot: mean covariance  \nCommon filename: %s*%s',fname.s,fname.e),'FontSize',FS(12),'FontWeight','Bold');
ylabel('<----- low (poor quality) --- mean covariance --- large (good quality)------>  ','FontSize',FS(10),'FontWeight','Bold');
xlabel('<----- first --- file order --- last ------>  ','FontSize',FS(10),'FontWeight','Bold');
hold off

% covariance
f = figure(4);
ws = spm('Winsize','Graphics');

set(f,'Name','Click in image to get file names','NumberTitle','off');
h = datacursormode(f);
set(h,'UpdateFcn',@myupdatefcn,'SnapToDataVertex','on','Enable','on');
set(f,'MenuBar','none','Position',[10 10 ws(3) ws(3)]);

cmap = [gray(64); hot(64)];

% scale YpY to 0..1
mn = min(YpY(:));
mx = max(YpY(:));
YpY_scaled = (YpY - mn)/(mx - mn);
YpYsorted_scaled = (YpYsorted - mn)/(mx - mn);

% show upper right triangle in gray
ind_tril = find(tril(ones(size(YpY))));
ima = YpY_scaled;
ima(ind_tril) = 0;
ima(ind_tril) = 1 + 1/64 + YpY_scaled(ind_tril);
image(64*ima)
a = gca;
set(a,'XTickLabel','','YTickLabel','');
axis image
xlabel('<----- first --- file order --- last ------>  ','FontSize',10,'FontWeight','Bold');
ylabel('<----- last --- file order --- first ------>  ','FontSize',10,'FontWeight','Bold');
title('Covariance','FontSize',12,'FontWeight','Bold');
colormap(cmap)

% ordered covariance
f = figure(5);
set(f,'Name','Click in image to get file names','NumberTitle','off');
h = datacursormode(f);
set(h,'UpdateFcn',@myupdatefcn_ordered,'SnapToDataVertex','on','Enable','on');
set(f,'MenuBar','none','Position',[11+ws(3) 10 ws(3) ws(3)]);

% show upper right triangle in gray
ind_tril = find(tril(ones(size(YpY))));
ima = YpYsorted_scaled;
ima(ind_tril) = 0;
ima(ind_tril) = 1 + 1/64 + YpYsorted_scaled(ind_tril);
image(64*ima)
if n_thresholded <= n
  hold on
  line([n_thresholded-0.5, n_thresholded-0.5], [0.5,n_thresholded-0.5])
  line([0.5,n_thresholded-0.5],[n_thresholded-0.5, n_thresholded-0.5])
  hold off
end
a = gca;
set(a,'XTickLabel','','YTickLabel','');
axis image
xlabel('<----- high --- mean covariance --- low ------>  ','FontSize',10,'FontWeight','Bold');
ylabel('<----- low --- mean covariance --- high ------>  ','FontSize',10,'FontWeight','Bold');
title({'Sorted Covariance','Blue line indicates 2-SD threshold'},'FontSize',12,'FontWeight','Bold');
colormap(cmap)

% slice preview
f = figure(6);
set(f,'MenuBar','none','Name','Slice preview','NumberTitle','off','Position',[12+2*ws(3) 10 2*V(1).dim(2) 4*V(1).dim(1)]);

% Close button
hCloseButton = uicontrol(f,...
        'position',[V(1).dim(2)-40 4*V(1).dim(1)-25 80 20],...
        'style','Pushbutton',...
        'string','Close',...
        'callback','try close(6); end; try close(5); end;try close(4);end;',...
        'ToolTipString','Close windows',...
        'Interruptible','on','Enable','on');

% range 0..64
slice_array = 64*slice_array/max(slice_array(:));

% check for replicates
for i=1:n
  for j=1:n
  if (i>j) & (mean_cov(i) == mean_cov(j))
    [s,differ] = unix(['diff ' V(i).fname ' ' V(j).fname]);
    if (s==0), fprintf(['\nWarning: ' V(i).fname ' and ' V(j).fname ' are same files?\n']); end
  end
  end
end

%-End
%-----------------------------------------------------------------------
spm_progress_bar('Clear')

show = spm_input('Show files with poorest cov?','+1','yes|no',[1 0],2);
if show
  number = min([n 24]);
  number = spm_input('How many files ?','+1','e',number);
  
  list = str2mat(V(ind(n:-1:1)).fname);
  list2 = list(1:number,:);
  spm_check_registration(list2)
end
return

%-----------------------------------------------------------------------
function txt = myupdatefcn(obj, event_obj)
%-----------------------------------------------------------------------
global fname jY h1 h2 YpY slice_array
pos = get(event_obj, 'Position');
h = gca;

x = pos(1);
y = pos(2);

txt = {sprintf('Covariance: %3.3f',YpY(x,y)),fname.m{x},fname.m{y}};

f = figure(6);
img = [slice_array(:,:,x); slice_array(:,:,y)];
image(img)
p = get(f,'Position');
p(3:4) = 2*size(img');
set(f,'Position',p);
set(f,'MenuBar','none','Colormap',gray);
set(gca,'XTickLabel','','YTickLabel','');
h = xlabel({['Top: ',fname.m{x}],['Bottom: ',fname.m{y}]});
set(h,'Interpreter','none');
axis image

return

%-----------------------------------------------------------------------
function txt = myupdatefcn_ordered(obj, event_obj)
%-----------------------------------------------------------------------
global fname jY h1 h2 YpY slice_array
pos = get(event_obj, 'Position');
h = gca;

x = jY(pos(1));
y = jY(pos(2));

txt = {sprintf('Covariance: %3.3f',YpY(x,y)),fname.m{x},fname.m{y}};

f = figure(6);
img = [slice_array(:,:,x); slice_array(:,:,y)];
image(img)
p = get(f,'Position');
p(3:4) = 2*size(img');
set(f,'Position',p);
set(f,'MenuBar','none','Colormap',gray);
set(gca,'XTickLabel','','YTickLabel','');
h = xlabel({['Top: ',fname.m{x}],['Bottom: ',fname.m{y}]});
set(h,'Interpreter','none');
axis image

return
