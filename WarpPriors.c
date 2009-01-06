/*
 * Christian Gaser
 * $Id$ 
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "optimizer3d.h"
#include "diffeo3d.h"
#include "Amap.h"

struct dartel_prm {
  int rform;         /* regularization form: 0 - linear elastic energy; 1 - membrane energy; 2 - bending energy */
  double rparam[6];  /* regularization parameters */
  double lmreg;      /* LM regularization */
  int cycles;        /* number of cycles for full multi grid (FMG) */
  int its;           /* Number of relaxation iterations in each multigrid cycle */
  int k;             /* time steps for solving the PDE */
  int code;          /* objective function: 0 - sum of squares; 1 - symmetric sum of squares; 2 - multinomial */
};

/* First order hold resampling - trilinear interpolation */
void subsample_up(float *vol, double *out, int dim_samp[3], int dim[3])
{
  int i, x, y, z, samp[3];
  double k111,k112,k121,k122,k211,k212,k221,k222;
  double dx1, dx2, dy1, dy2, dz1, dz2, xi, yi, zi;
  int off1, off2, xcoord, ycoord, zcoord;

  for (i=0; i<3; i++) samp[i] = (int)ceil((double)dim[i]/(double)dim_samp[i]);
  
  for (z=0; z<dim[2]; z++) {
    zi = 1.0+(double)z/(double)samp[2];
    for (y=0; y<dim[1]; y++) {
      yi = 1.0+(double)y/(double)samp[1];
      for (x=0; x<dim[0]; x++) {
        xi = 1.0+(double)x/(double)samp[0];
        i = z*dim[0]*dim[1] + y*dim[0] + x;

        if (zi>=0 && zi<dim_samp[2] && yi>=0 && yi<dim_samp[1] && xi>=0 && xi<dim_samp[0])  {
          xcoord = (int)floor(xi); dx1=xi-(double)xcoord; dx2=1.0-dx1;
          ycoord = (int)floor(yi); dy1=yi-(double)ycoord; dy2=1.0-dy1;
          zcoord = (int)floor(zi); dz1=zi-(double)zcoord; dz2=1.0-dz1;

          off1 = xcoord-1 + dim_samp[0]*(ycoord-1 + dim_samp[1]*(zcoord-1));
          k222 = vol[off1]; k122 = vol[off1+1]; off2 = off1+dim_samp[0];
          k212 = vol[off2]; k112 = vol[off2+1]; off1+= dim_samp[0]*dim_samp[1];
          k221 = vol[off1]; k121 = vol[off1+1]; off2 = off1+dim_samp[0];
          k211 = vol[off2]; k111 = vol[off2+1];

          out[i] = (((k222*dx2 + k122*dx1)*dy2 + (k212*dx2 + k112*dx1)*dy1))*dz2
                 + (((k221*dx2 + k121*dx1)*dy2 + (k211*dx2 + k111*dx1)*dy1))*dz1;
                 
        } else out[i] = 0;
      }
    }
  }
}

/* First order hold resampling - trilinear interpolation */
void subsample_down(unsigned char *vol, float *out, int dim_samp[3], int dim[3], int offset, int offset_samp)
{
  int i, x, y, z;
  double k111,k112,k121,k122,k211,k212,k221,k222;
  double dx1, dx2, dy1, dy2, dz1, dz2, xi, yi, zi, samp[3];
  int off1, off2, xcoord, ycoord, zcoord;

  for (i=0; i<3; i++) samp[i] = (int)ceil((double)dim_samp[i]/(double)dim[i]);
  
  for (z=0; z<dim[2]; z++) {
    zi = 1.0+(double)z*(double)samp[2];
    for (y=0; y<dim[1]; y++) {
      yi = 1.0+(double)y*(double)samp[1];
      for (x=0; x<dim[0]; x++) {
        xi = 1.0+(double)x*(double)samp[0];
        i = z*dim[0]*dim[1] + y*dim[0] + x + offset;

        if (zi>=0 && zi<dim_samp[2] && yi>=0 && yi<dim_samp[1] && xi>=0 && xi<dim_samp[0])  {
          xcoord = (int)floor(xi); dx1=xi-(double)xcoord; dx2=1.0-dx1;
          ycoord = (int)floor(yi); dy1=yi-(double)ycoord; dy2=1.0-dy1;
          zcoord = (int)floor(zi); dz1=zi-(double)zcoord; dz2=1.0-dz1;

          off1 = xcoord-1 + dim_samp[0]*(ycoord-1 + dim_samp[1]*(zcoord-1)) + offset_samp;
          k222 = (double)vol[off1]; k122 = (double)vol[off1+1]; off2 = off1+dim_samp[0];
          k212 = (double)vol[off2]; k112 = (double)vol[off2+1]; off1+= dim_samp[0]*dim_samp[1];
          k221 = (double)vol[off1]; k121 = (double)vol[off1+1]; off2 = off1+dim_samp[0];
          k211 = (double)vol[off2]; k111 = (double)vol[off2+1];

          out[i] = (float)((((k222*dx2 + k122*dx1)*dy2 + (k212*dx2 + k112*dx1)*dy1))*dz2
                         + (((k221*dx2 + k121*dx1)*dy2 + (k211*dx2 + k111*dx1)*dy1))*dz1);
                 
        } else out[i] = 0;
      }
    }
  }
}

void WarpPriors(unsigned char *prob, unsigned char *priors, unsigned char *mask, float *flow, int *dims, int loop)
{
  int vol_samp, vol, vol2, vol3, vol_samp2, vol_samp3, i, j;
  int size_samp[4], samp, area;
  double buf[3], ll[3], samp_1; 
  float *f, *g, *v, *flow1, *scratch, *mask_samp, *mask_samp2, max;
  double *mask_double;
  int it, it0, it1, it_scratch, ndims4, dims_samp[3], area_samp;
   
  int code = 2;    /* multinomial */
  int rform = 0;   /* linear energy */
  double lmreg = 0.01;
  static double param[3] = {1.0, 1.0, 1.0};

  samp = 4;
    
  /* only use gm/wm */
  ndims4 = 2;

  /* define grid dimensions */
  for(j=0; j<3; j++) dims_samp[j] = (int) ceil((dims[j]-1)/((double) samp))+1;
  
  /* find grid point conversion factor */
  samp_1 = 1.0/((double) samp);

  area = dims[0]*dims[1];
  vol  = dims[0]*dims[1]*dims[2];
  vol2 = 2*vol;
  vol3 = 3*vol;
  area_samp = dims_samp[0]*dims_samp[1];
  vol_samp  = dims_samp[0]*dims_samp[1]*dims_samp[2];
  vol_samp2 = 2*vol_samp;
  vol_samp3 = 3*vol_samp;
  
  f      = (float *)malloc(sizeof(float)*vol_samp3);
  g      = (float *)malloc(sizeof(float)*vol_samp3);
  v      = (float *)malloc(sizeof(float)*vol_samp3);
  flow1  = (float *)malloc(sizeof(float)*vol_samp3);
  mask_double = (double *)malloc(sizeof(double)*vol);
  mask_samp  = (float *)malloc(sizeof(float)*vol_samp);
  mask_samp2 = (float *)malloc(sizeof(float)*vol_samp);

  /* initialize size of subsampled data and add 4th dimension */
  for(i=0; i < 3; i++) size_samp[i] = dims_samp[i];    
  size_samp[3] = ndims4;

  /* initialize flow field */
  for (i = 0; i < vol_samp3; i++) v[i] = flow[i];

  struct dartel_prm* prm = (struct dartel_prm*)malloc(sizeof(struct dartel_prm)*10);
  
  /* first three entries of param are equal */
  for (j = 0; j < loop; j++)
    for (i = 0; i < 3; i++)  prm[j].rparam[i] = param[i];

  /* some entries are equal */
  for (j = 0; j < loop; j++) {
    prm[j].rform = rform;
    prm[j].cycles = 3;
    prm[j].its = 3;
    prm[j].code = code;
    prm[j].lmreg = lmreg;
  }

  prm[0].rparam[3] = 4.0;   prm[0].rparam[4] = 2.0;    prm[0].rparam[5] = 1e-6; prm[0].k = 0; 
  prm[1].rparam[3] = 2.0;   prm[1].rparam[4] = 1.0;    prm[1].rparam[5] = 1e-6; prm[1].k = 0; 
  prm[2].rparam[3] = 1.0;   prm[2].rparam[4] = 0.5;    prm[2].rparam[5] = 1e-6; prm[2].k = 1; 
  prm[3].rparam[3] = 0.5;   prm[3].rparam[4] = 0.25;   prm[3].rparam[5] = 1e-6; prm[3].k = 2; 
  prm[4].rparam[3] = 0.25;  prm[4].rparam[4] = 0.125;  prm[4].rparam[5] = 1e-6; prm[4].k = 4; 
  prm[5].rparam[3] = 0.125; prm[5].rparam[4] = 0.0625; prm[5].rparam[5] = 1e-6; prm[5].k = 6;

  /* subsample priors and mask to lower resolution */
  subsample_down(mask, mask_samp, dims, dims_samp, 0, 0);    
  subsample_down(priors, f, dims, dims_samp, 0, 0);    
  subsample_down(priors, f, dims, dims_samp, vol_samp, vol);    
  subsample_down(priors, f, dims, dims_samp, vol_samp2, vol2);    

  /* scale subsampled priors to a maximum of 1 */
  max = -1e15;
  for (i=0; i<vol_samp3; i++) max = MAX(f[i], max);
  for (i=0; i<vol_samp3; i++) f[i] /= max;

  /* subsample probabilities and reorder from CSF/GM/WM to GM/WM/CSF */
  subsample_down(prob, g, dims, dims_samp, 0, vol);    
  subsample_down(prob, g, dims, dims_samp, vol_samp, vol2);    
  subsample_down(prob, g, dims, dims_samp, vol_samp2, 0);    

  /* scale subsampled probabilities to a maximum of 1 */
  max = -1e15;
  for (i=0; i<vol_samp3; i++) max = MAX(g[i], max);
  for (i=0; i<vol_samp3; i++) g[i] /= max;

  /* iterative warping using dartel approach */
  it = 0;
  for (it0 = 0; it0 < loop; it0++) {
    it_scratch = iteration_scratchsize((int *)size_samp, prm[it0].code, prm[it0].k);
    scratch = (float *)malloc(sizeof(float)*it_scratch);

    for (it1 = 0; it1 < prm[it0].its; it1++) {
      it++;
      iteration(size_samp, prm[it0].k, v, f, g, (float *)0, prm[it0].rform, prm[it0].rparam, prm[it0].lmreg, 
        prm[it0].cycles, prm[it0].its, prm[it0].code, flow, ll, scratch);              
      printf("%02d:\t%.2f\t%6.2f\t%6.2f\t%6.2f\n", it, ll[0], ll[1], ll[0]+ll[1], ll[2]);
      fflush(stdout);
      for (i = 0; i < vol_samp3; i++) v[i] = flow[i];
    }
    free(scratch);
  }
  
  /* use exponentional flow */
  expdef(size_samp, 6, -1, v, flow, flow1, (float *)0, (float *)0); 

  /* apply deformation field */
  for (i = 0; i < vol_samp; i++) {
    sampn(dims_samp, mask_samp, 1, vol_samp, flow[i]+8.0, flow[i+vol_samp]+8.0, flow[i+vol_samp2]+8.0, buf);
    mask_samp2[i] = (float)buf[0];
  }

  /* resample subsampled mask image to original resolution */
  subsample_up(mask_samp2, mask_double, dims_samp, dims);    
  for (i = 0; i < vol; i++) mask[i] = (unsigned char) ROUND(mask_double[i]);
  
  /* rescue flow field */
  for (i = 0; i < vol_samp3; i++) flow[i] = v[i];

  free(prm);
  free(flow1);
  free(mask_samp);
  free(mask_samp2);
  free(mask_double);
  free(v);
  free(f);
  free(g);

}