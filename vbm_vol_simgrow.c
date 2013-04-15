#include "mex.h"   
#include "matrix.h"
#include "math.h"

// HELPFUNCTIONS

// estimate x,y,z position of index i in an array size sx,sxy=sx*sy...
void ind2sub(int i,int *x,int *y, int *z, int sxy, int sy) {
  *z = floor( i / (sxy) ) +1; 
   i = i % (sxy);
  *y = floor( i / sy ) +1;        
  *x = i % sy + 1;
}

int sub2ind(int x,int y, int z, const int s[]) {
  int i=(z-1)*s[0]*s[1] + (y-1)*s[0] + (x-1);
  if (i<0 || i>s[0]*s[1]*s[2]) i=1;
  return i;
}

float abs2(float n) {	if (n<0) return -n; else return n; }
float sign(float n) {	if (n<0) return 1; else return 0; }
float max2(float a, float b) { if (a>b) return a; else return b; }

// MAINFUNCTION
/* ROI, F, 1 */
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
  if (nrhs<1)                                                      mexErrMsgTxt("ERROR:down_cut01: not enought input elements\n");
  if (nrhs>5)                                                      mexErrMsgTxt("ERROR:down_cut01: to many input elements.\n");
  if (nlhs>2)                                                      mexErrMsgTxt("ERROR:down_cut01: to many output elements.\n");
  if (mxIsSingle(prhs[0])==0)                                      mexErrMsgTxt("ERROR:down_cut01: first  input must be an 3d single matrix\n");
  if (mxIsSingle(prhs[1])==0)                                      mexErrMsgTxt("ERROR:down_cut01: second input must be an 3d single matrix\n");
  if (mxIsDouble(prhs[2])==0 || mxGetNumberOfElements(prhs[2])!=1) mexErrMsgTxt("ERROR:down_cut01: third input must one double value\n");
  
  if (nrhs==4 && mxIsDouble(prhs[3])==0)                           mexErrMsgTxt("ERROR:down_cut01: fourth  input must be an double matrix\n");
  if (nrhs==4 && mxGetNumberOfElements(prhs[3])!=3)                mexErrMsgTxt("ERROR:down_cut01: fourth input must have 3 Elements");
  if (nrhs==5 && mxIsDouble(prhs[4])==0)                           mexErrMsgTxt("ERROR:down_cut01: fifth input must be an double matrix\n");
  if (nrhs==5 && mxGetNumberOfElements(prhs[4])!=2)                mexErrMsgTxt("ERROR:down_cut01: fifht input must have 2 Elements");
    
  // main informations about input data (size, dimensions, ...)
  const mwSize *sL = mxGetDimensions(prhs[0]); int sSEG[] = {sL[0],sL[1],sL[2]}; 
  const int     dL = mxGetNumberOfDimensions(prhs[0]);
  const int     nL = mxGetNumberOfElements(prhs[0]);
  const int     x  = sL[0];
  const int     y  = sL[1];
  const int     xy = x*y;

  const int sSS[] = {1,3}, sdsv[] = {1,2}; 
  mxArray *SS  = mxCreateNumericArray(2,sSS, mxDOUBLE_CLASS,mxREAL); double*S  = mxGetPr(SS);
  mxArray *dsv = mxCreateNumericArray(2,sdsv,mxDOUBLE_CLASS,mxREAL); double*dd = mxGetPr(dsv);
  float dI=0.0; double*SEGd; if (nrhs>=3) {SEGd=mxGetPr(prhs[2]); dI=(float) SEGd[0];}; 
  if (nrhs<4) {S[0]=1; S[1]=1; S[2]=1;} else {S=mxGetPr(prhs[3]);}
  if (nrhs<5) {dd[0]=0.1; dd[1]=10;}    else {dd=mxGetPr(prhs[4]);}
  
  float s1 = abs2((float)S[0]),s2 = abs2((float)S[1]),s3 = abs2((float)S[2]);
  const float   s12  = sqrt( s1*s1  + s2*s2); // xy - voxel size
  const float   s13  = sqrt( s1*s1  + s3*s3); // xz - voxel size
  const float   s23  = sqrt( s2*s2  + s3*s3); // yz - voxel size
  const float   s123 = sqrt(s12*s12 + s3*s3); // xyz - voxel size
  const int     nr = nrhs;
  
  // indices of the neighbor Ni (index distance) and euclidean distance NW
  const int   NI[]  = {  1, -1,  x, -x, xy,-xy, -x-1,-x+1,x-1,x+1, -xy-1,-xy+1,xy-1,xy+1, -xy-x,-xy+x,xy-x,xy+x,  -xy-x-1,-xy-x+1,-xy+x-1,-xy+x+1, xy-x-1,xy-x+1,xy+x-1,xy+x+1};  
  const float ND[]  = { s1, s1, s2, s2, s3, s3,  s12, s12,s12,s12,   s13,  s13, s13, s13,   s23,  s23, s23, s23,     s123,   s123,   s123,   s123,   s123,  s123,  s123,  s123};
 
  float 			du, dv, dw, dnu, dnv, dnw, d, dcf, WMu, WMv, WMw, GMu, GMv, GMw, SEGl, SEGu, tmpfloat;
  int         i,n,ni,DNi,u,v,w,nu,nv,nw, tmpint, cmi;
    
  // main volumes - actual without memory optimation ...
  plhs[0] = mxCreateNumericArray(dL,sL,mxSINGLE_CLASS,mxREAL); // label map 
  plhs[1] = mxCreateNumericArray(dL,sL,mxSINGLE_CLASS,mxREAL); // tissue map (speed)
    
  // input variables
  float*ALAB = (float *)mxGetPr(prhs[0]);	// label map
  float*SEG  = (float *)mxGetPr(prhs[1]);	// tissue map
  
  // output variables
  float*SLAB = (float *)mxGetPr(plhs[0]);	// label map
  float*DIST = (float *)mxGetPr(plhs[1]);	// distance map
  
  int	  nCV = 0; 		// # voxel of interest (negative voxel that have to processed) 
	int 	kll;
	int 	kllv = 2000;
	float DISTN, nmaxD, down;
	float Dmax = 0.2;
  int   noLABnb;
	
  
	// initialisation of parameter volumes
	for (i=0;i<nL;i++) { 
		SLAB[i] = ALAB[i]; 
		if (SLAB[i]==NAN) SLAB[i]=0;
		if (SLAB[i]==0) 					{DIST[i]= INFINITY; } 
		else {
			if (SLAB[i]==-INFINITY) {DIST[i]=-INFINITY; }
			else 										{DIST[i]=0; nCV++;} } 
	}
	// diffusion 
	int   nC = nCV;
	kll=0;
	while ( nCV>0 && kll<kllv && nC>0 ) {
		kll++; nC=0;
	
		for (i=0;i<nL;i++) { 
			if ( (DIST[i]<=0) && (DIST[i]!=-INFINITY ) ) { 
				if (DIST[i]<0) DIST[i]=-DIST[i]; 
				nCV--; // demark points - also the with zero distance
				
				ind2sub(i,&u,&v,&w,xy,x); 
				for (n=0;n<26;n++) {
					ni = i+NI[n]; ind2sub(ni,&nu,&nv,&nw,xy,x);
					
					if ( ((ni<0) || (ni>=nL) || (abs(nu-u)>1) || (abs(nv-v)>1) || (abs(nw-w)>1) )==0 && (abs2(SEG[i]-SEG[ni])<(dI*SEG[i]*SEG[i])) && ALAB[ni]==0 ) {
            //if (nrhs==5) DISTN = DIST[i] + dd[0]*ND[n] + dd[1]*max2(0,SEG[ni]);  
            //else         DISTN = DIST[i] + dd[0]*ND[n] + dd[1]*max2(0,4-SEG[ni]);
            DISTN = DIST[i] + abs2(SEG[i]-SEG[ni]);
            
						//if ( DISTN>0 && (abs2(DIST[ni])>abs2(DISTN)) &&  (( (ni<0) || (ni>=nL) || (abs(nu-u)>1) || (abs(nv-v)>1) || (abs(nw-w)>1) )==0)  )  {
						if (  (DIST[ni]!=-INFINITY) && (abs2(DIST[ni])>abs2(DISTN)) && DISTN<Dmax)  {	
							if (DIST[ni]>0) nCV++; nC++;
							DIST[ni] = -DISTN;
							SLAB[ni] = SLAB[i];
						}
					}				
				}
				if (DIST[i]==0) DIST[i]=-INFINITY; // demark start points
				
			}
		}
		
	}

	for (i=0;i<nL;i++) { if (DIST[i]==-INFINITY) {DIST[i]=0; } }

	//printf("(%d,%d)",nCV,kll);	
}