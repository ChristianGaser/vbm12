#!/usr/bin/env make -f
#
# $Id$

include Makefile.var

OBS  = Amap.o KmeansProper.o MrfPrior.o Pve.o
OBS1 = Amap.o Kmeans.o MrfPrior.o Pve.o SplineSmooth.o
OBS2 = PveAmap.o Amap.o MrfPrior.o Pve.o Kmeans.o WarpPriors.o Bayes.o optimizer3d.o diffeo3d.o SplineSmooth.o
OBS3 = ornlm.o

all: AmapMex.$(SUF) ornlmMex.$(SUF) AmapMexNu.$(SUF)

AmapMex.$(SUF): AmapMex.c $(OBS)
	$(MEX) AmapMex.c $(OBS) $(MEXEND)

AmapMexNu.$(SUF): AmapMexNu.c $(OBS1)
	$(MEX) AmapMexNu.c $(OBS1) $(MEXEND) ./$(EXT)/libEBTKS.a $(MEXEND)

ornlmMex.$(SUF): ornlmMex.c $(OBS3)
	$(MEX) ornlmMex.c $(OBS3) $(MEXEND)

PveAmapMex.$(SUF): PveAmapMex.c $(OBS2)
	$(MEX) PveAmapMex.c $(OBS2) -I. ./$(EXT)/libEBTKS.a $(MEXEND)

%.o : %.c
	$(CC) -fPIC -c -O2 $< $(MEXEND)

SplineSmooth.o : SplineSmooth.cc
	$(CXX) -fPIC -O2 -I. -c $< $(MEXEND)

%.$(SUF) : %.c %.cc
	$(MEX)  $< $(MEXEND)

clean: 
	$(DEL) $(OBS) $(OBS1) $(OBS2) AmapMex.$(SUF).a

-include Makefile.vbm

