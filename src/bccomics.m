%%
%% BCCOMICS: Reads in fluctuation (curvature*TF) made by bccomics_setup.m.
%%           Generates 3D fields of small-scale (inside-a-patch)
%%           perturbations into bare binary files. 
%%
%% Author: Kyungjin Ahn
%%
%% This MATLAB(R) / GNU Octave code is freely distributed, and you are
%% free to modify it or port it into other languages. BCCOMICS is under
%% an absolutely no-warranty condition. It is assumed that you consent
%% to one condition: when you get scientific results using BCCOMICS
%% and publish them, in your paper you need to cite this paper
%% (please use journal-provided id after publication),
%% ---------
%% Ahn & Smith 2018, arXiv:1807.04063 (AS18).
%% ---------
%% For detailed theoretical background, please cite this paper
%% (not a requirement for using this code though)
%% ---------
%% Ahn 2016, ApJ 830:68 (A16).
%% ---------
%%
%% Other references:
%%   Ma & Bertschinger 1995, ApJ 455, 7 (MB)
%%   Naoz & Barkana 2005, MNRAS 362, 1047 (NB)
%%   Tseliakhovich & Hirata 2010, PRD, 82, 083520 (TH)
%%
%%
%% What it does: This code reads in a fluctuation (~curvature*transfer-function)
%%               and monopole (e.g. V_cb of a patch) data generated by 
%%               bccomics_setup. For any wavevector k, the read in data
%%               is interpolated onto (k, mu). Then random seed is applied,
%%               and FFT is performed.
%%               For initial condition readable by enzo, a conversion script
%%               of this binary into hdf5 is provided ("convert_enzo.py").
%%               Conversion sripts for other codes are welcomed!!
%% 
%%               
%% Some details:
%% ----------
%% Just uniform-grid initial condition only. No nested grid IC yet.
%% Binary files from bccomics_setup.m is also in hdf5 format, so
%% porting bccomics.m into other languages & improving it is also welcomed.

more off; %% enables to see progress
returnflag = false; %% main program need to stop when script stops.

%% Detect which is running: octave or matlab?
if (exist('OCTAVE_VERSION','builtin'))
  matlabflag=false;
else
  matlabflag=true;
end

%% Some old versions of gnu octave has buggy ifftshift routine, so for
%% octave version older than 4.0.1, just use working one under the provided
%% directory. In case statistics package (for raylrnd) is not installed,
%% use provided statistics package.
%% All this can be avoided by upgrading to most recent
%% octave version and installing octave-statistics package.
if ~matlabflag
  if compare_versions(OCTAVE_VERSION,'4.0.1','<')
    %% Messages "warning: function * shadows ..." should be welcomed.
    addpath('mfiles_for_octave'); 
  end
  if ~exist('raylrnd')
    addpath('statistics-1.3.0/inst');
  end
end

%% Read in constants in cgs unit and conversion factors.
Consts_Conversions;  %%==== script ==================
%% Read in cosmology
run(Cosmology);  %%==== script ==================
%% Read in parameters
params;  %%==== script ==================
if (mod(Ncell_p,2)==1)
  disp('Choose an even number for Ncell_p');
  clear;
  return;
end
%% Setting resolution etc.
%% index for center of k-space (e.g. if 6 sample points exist, 4th is the
%% center, not 3rd). This convention for even number is different from that
%% in p.69 of "DFT: An Owner Manual ..." by W. Briggs.
%% k index runs from -N/2 to N/2-1 in this code, but DFT book uses
%% -N/2+1 to N/2. Had to choose the former convention due to FFT convention
%% of Matlab and Octave for even numbered case.
patch_init;  %%==== script ==================

interp2opt = 'cubic'

k1_3D_p = zeros(Nmode_p,Nmode_p,Nmode_p);
k2_3D_p = zeros(Nmode_p,Nmode_p,Nmode_p);
k3_3D_p = zeros(Nmode_p,Nmode_p,Nmode_p);

%%%%%% Below can be replaced by (shifted meshgrid)*coeff.
%% For assigning k, see p.69 of "DFT..." by W. Briggs.
%% k1 component on each (k1,k2,k3) point, as a 3D matrix
for ik=-Nhalf_p:Nhalf_p-1
  k1                 = kunit_p*ik;
  iksft              = ik + Nhalf_p+1;
  k1_3D_p(iksft,:,:) = k1;
end
%% k2 component on each (k1,k2,k3) point, as a 3D matrix
for jk=-Nhalf_p:Nhalf_p-1
  k2                 = kunit_p*jk;
  jksft              = jk + Nhalf_p+1;
  k2_3D_p(:,jksft,:) = k2;
end
%% k3 component on each (k1,k2,k3) point, as a 3D matrix
for kk=-Nhalf_p:Nhalf_p-1
  k3                 = kunit_p*kk;
  kksft              = kk + Nhalf_p+1;
  k3_3D_p(:,:,kksft) = k3;
end

ksq_p     = k1_3D_p.^2 +k2_3D_p.^2 +k3_3D_p.^2;

%% utilize above for rvector too, but just in memory saving way (****)
%%r1 = k1_3D_p/kunit_p;
%%r2 = k2_3D_p/kunit_p;
%%r3 = k3_3D_p/kunit_p;

%% read in mu and ksample info.
mu  = load('mu.dat');
dmu = mu(2)-mu(1);
Nmu = length(mu);

ksampletab = load('ksample.dat');
Nsample    = length(ksampletab);

%% read in V_cb field: V_cb = Vc-Vb
if matlabflag
  load([setupdir 'V_cb_1_azend.dat'], '-mat', 'V_cb_1_azend');  
  load([setupdir 'V_cb_2_azend.dat'], '-mat', 'V_cb_2_azend');
  load([setupdir 'V_cb_3_azend.dat'], '-mat', 'V_cb_3_azend');
  load([setupdir 'DT_azend.dat'],     '-mat'  'DT3D_azend');
  load([setupdir 'Dc3D_azend.dat'],   '-mat', 'Dc3D_azend');
  load([setupdir 'Db3D_azend.dat'],   '-mat', 'Db3D_azend');
  load([setupdir 'THc3D_azend.dat'],  '-mat', 'THc3D_azend');
  load([setupdir 'THb3D_azend.dat'],  '-mat', 'THb3D_azend');
else
  load('-mat-binary', [setupdir 'V_cb_1_azend.dat'], 'V_cb_1_azend');
  load('-mat-binary', [setupdir 'V_cb_2_azend.dat'], 'V_cb_2_azend');
  load('-mat-binary', [setupdir 'V_cb_3_azend.dat'], 'V_cb_3_azend');
  load('-mat-binary', [setupdir 'DT_azend.dat'],     'DT3D_azend');
  load('-mat-binary', [setupdir 'Dc3D_azend.dat'],   'Dc3D_azend');
  load('-mat-binary', [setupdir 'Db3D_azend.dat'],   'Db3D_azend');
  load('-mat-binary', [setupdir 'THc3D_azend.dat'],  'THc3D_azend');
  load('-mat-binary', [setupdir 'THb3D_azend.dat'],  'THb3D_azend');
end

%% choose cell whose small scale fluctuations to calculate
icc = load([setupdir 'icc.dat']);
Ncc = length(icc(:,1)) %% # of chosen cells

%% read in the redshift
zz    = load([setupdir 'zz.dat']);
zzbegin = zz(1);
zzend   = zz(2);
azbegin = 1/(1+zzbegin);
azend   = 1/(1+zzend);

%% prepare for initial conditions for enzo
zf = zzend;  %% redshift for initial condition
af = 1/(1+zf);  %% scale factor for initial condition
%% units are all in cgs (from enzo CosmologyGetUnits.C)
Lbox_p_inMpch = Lbox_p*h;  %% enzo uses 'ComovingBoxSize' in units of Mpc/h
%% enzo length unit is for anything in proper distance centimeter. So if one has something in comoving distance Mpc, one just needs to divide it by box size in units of comoving Mpc.
DensityUnits  = 1.8788e-29*Om0*h^2*(1+zf)^3;
VelocityUnits = 1.22475e7*Lbox_p_inMpch*sqrt(Om0)*sqrt(1+zf);
SpecificEnergyUnits = VelocityUnits^2; %% specific energy = energy/mass 

fout = fopen('Units.txt','w');
fprintf(fout,'%s\n', '## density units; velocity units; specific energy units -- for enzo');
fprintf(fout,'%e %e %e\n', DensityUnits, VelocityUnits, SpecificEnergyUnits);
fclose(fout);


%% keep phases, which has been inherited from the initial(z=1000) transfer function
%% Treat deltas*_Ahn_cell_mu as the transfer function with the correct relative phases.
%%$$
%%$$ 1:cdm-density; 2:baryon-density; 3: cdm-vel-divergence; 4:baryon-vel-divergence;
%%$$ 5: baryon-temperature
%%deltas_mu             = zeros(Ncc, Nsample, Nmu, 5); %%$$  -- LATER
deltasc_Ahn_cell_mu   = zeros(Ncc, Nsample, Nmu);
deltasb_Ahn_cell_mu   = zeros(Ncc, Nsample, Nmu);
deltasThc_Ahn_cell_mu = zeros(Ncc, Nsample, Nmu);
deltasThb_Ahn_cell_mu = zeros(Ncc, Nsample, Nmu);
deltasT_Ahn_cell_mu   = zeros(Ncc, Nsample, Nmu);

for isample=1:Nsample
  ksample = ksampletab(isample);
  for idxcc = 1:Ncc
    %% load calculated deltas
    ic = icc(idxcc,1);
    jc = icc(idxcc,2);
    kc = icc(idxcc,3);

    stroutD    = ['Deltas_Ahn_1Dmu_k' num2str(ksample)];
    stroutD    = [stroutD '_ic' num2str(ic) '_jc' num2str(jc) '_kc' num2str(kc) '-muhalf.matbin'];

    if matlabflag
      load(stroutD, '-mat', 'ksampletab', 'deltasc', 'deltasb', 'deltasThc', 'deltasThb', 'deltasT');
    else
      load('-mat-binary', stroutD, 'ksampletab', 'deltasc', 'deltasb', 'deltasThc', 'deltasThb', 'deltasT');
    end
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@2
    deltasc_Ahn   = DDAhn.deltasc_Ahn;
    deltasb_Ahn   = DDAhn.deltasb_Ahn;
    deltasThc_Ahn = DDAhn.deltasThc_Ahn;
    deltasThb_Ahn = DDAhn.deltasThb_Ahn;
    deltasT_Ahn   = DDAhn.deltasT_Ahn;
    
    %% for given cell (index for chosen cell: icc)
    %% cos(angle), where angle is that between k-vector and V_cb vector.
    %% OK to use initial V_cb fields, because the V_cb vector does not change
    %% direction over time.
    ic=icc(idxcc,1);
    jc=icc(idxcc,2);
    kc=icc(idxcc,3);
    deltasc_Ahn_cell_mu(idxcc, isample, :)   = reshape(deltasc_Ahn,1,1,Nmu);
    deltasb_Ahn_cell_mu(idxcc, isample, :)   = reshape(deltasb_Ahn,1,1,Nmu);
    deltasThc_Ahn_cell_mu(idxcc, isample, :) = reshape(deltasThc_Ahn,1,1,Nmu);
    deltasThb_Ahn_cell_mu(idxcc, isample, :) = reshape(deltasThb_Ahn,1,1,Nmu);
    deltasT_Ahn_cell_mu(idxcc, isample, :)   = reshape(deltasT_Ahn,1,1,Nmu);
  end
end

%% some check
dsc10=reshape(deltasc_Ahn_cell_mu(1,:,1),Nsample,1); %% for mu=0 and under 1nd cell environment
dsb10=reshape(deltasb_Ahn_cell_mu(1,:,1),Nsample,1); %% for mu=0 and under 1nd cell environment
dsThc10=reshape(deltasThc_Ahn_cell_mu(1,:,1),Nsample,1); %% for mu=0 and under 1nd cell environment
dsThb10=reshape(deltasThb_Ahn_cell_mu(1,:,1),Nsample,1); %% for mu=0 and under 1nd cell environment

dsc20=reshape(deltasc_Ahn_cell_mu(2,:,1),Nsample,1); %% for mu=0 and under 2nd cell environment
dsb20=reshape(deltasb_Ahn_cell_mu(2,:,1),Nsample,1); %% for mu=0 and under 2nd cell environment
dsThc20=reshape(deltasThc_Ahn_cell_mu(2,:,1),Nsample,1); %% for mu=0 and under 2nd cell environment
dsThb20=reshape(deltasThb_Ahn_cell_mu(2,:,1),Nsample,1); %% for mu=0 and under 2nd cell environment

dsc11=reshape(deltasc_Ahn_cell_mu(1,:,Nmu),Nsample,1); %% for mu=0 and under 1nd cell environment
dsb11=reshape(deltasb_Ahn_cell_mu(1,:,Nmu),Nsample,1); %% for mu=0 and under 1nd cell environment
dsThc11=reshape(deltasThc_Ahn_cell_mu(1,:,Nmu),Nsample,1); %% for mu=0 and under 1nd cell environment
dsThb11=reshape(deltasThb_Ahn_cell_mu(1,:,Nmu),Nsample,1); %% for mu=0 and under 1nd cell environment

dsc21=reshape(deltasc_Ahn_cell_mu(2,:,Nmu),Nsample,1); %% for mu=0 and under 2nd cell environment
dsb21=reshape(deltasb_Ahn_cell_mu(2,:,Nmu),Nsample,1); %% for mu=0 and under 2nd cell environment
dsThc21=reshape(deltasThc_Ahn_cell_mu(2,:,Nmu),Nsample,1); %% for mu=0 and under 2nd cell environment
dsThb21=reshape(deltasThb_Ahn_cell_mu(2,:,Nmu),Nsample,1); %% for mu=0 and under 2nd cell environment

loglog(ksampletab,abs(dsc20), ksampletab,abs(dsb20))
loglog(ksampletab,abs(dsThc20), ksampletab,abs(dsThb20))
loglog(ksampletab,abs(dsc20), ksampletab,abs(dsThc20),'.')
loglog(ksampletab,real(dsc20), ksampletab,-real(dsThc20),'.')

plot(log10(ksampletab),abs(fc*dsc10+fb*dsb10).^2.*ksampletab.^3/(2*pi^2),log10(ksampletab),abs(fc*dsc11+fb*dsb11).^2.*ksampletab.^3/(2*pi^2),log10(ksampletab),abs(fc*dsc20+fb*dsb20).^2.*ksampletab.^3/(2*pi^2),log10(ksampletab),abs(fc*dsc21+fb*dsb21).^2.*ksampletab.^3/(2*pi^2))

plot(log10(ksampletab),abs(dsc10)./abs(dsc20))
plot(log10(ksampletab),abs(dsThc10)./abs(dsThc20))
plot(log10(ksampletab),abs(dsc11)./abs(dsc21))
plot(log10(ksampletab),abs(dsThc11)./abs(dsThc21))

testk   = [1.3; 1.6; 1.8; 3.5; 7.5; 43.5; 56.7];
testdsc = interp1(log10(ksampletab), abs(dsc10), log10(testk), 'cubic');
plot(log10(ksampletab),abs(dsc10), log10(testk), abs(testdsc))
loglog(ksampletab,abs(dsc10), testk, testdsc)


%% # of random numbers for amplitude and phase, for lower half of k space including center plane
%%if (~exist('subgaussseed.matbin'))
%%  Nrandamp = Nmode_p*Nmode_p*Nc_p;
%%  Nrandphs = Nrandamp;
%%
%%  randamp = raylrnd(1,     [Nrandamp,1]);
%%  randphs = unifrnd(0,2*pi,[Nrandphs,1]);
%%  save('-mat-binary', 'subgaussseed.matbin', 'randamp', 'randphs') %% octave
%%  %%save('subgaussseed.matbin', 'randamp', 'randphs', '-v6') %% matlab
%%else
%%  load '-mat-binary' 'subgaussseed.matbin' 'randamp' 'randphs' %% octave
%%  %%load 'subgaussseed.matbin' '-mat' 'randamp' 'randphs' %% matlab
%%  if (length(randamp) ~= Nmode_p*Nmode_p*Nc_p)
%%    Nrandamp = Nmode_p*Nmode_p*Nc_p;
%%    Nrandphs = Nrandamp;
%%
%%    randamp = raylrnd(1,     [Nrandamp,1]);
%%    randphs = unifrnd(0,2*pi,[Nrandphs,1]);
%%    save('-mat-binary', 'subgaussseed.matbin', 'randamp', 'randphs') %% octave
%%    %%save('subgaussseed.matbin', 'randamp', 'randphs', '-v6') %% matlab
%%  end
%%end

%% Above random seed reading does not generate the low-res version of the
%% high-res random seed. So, here read in the 512x512x127 random seed and
%% make correspondence.
load '-mat-binary' 'subgaussseed512.matbin' 'randamp' 'randphs' %% octave
%%load 'subgaussseed512.matbin' '-mat' 'randamp' 'randphs' %% matlab
randamp  = reshape(randamp, 512, 512, 257);
randphs  = reshape(randphs, 512, 512, 257);
Ncoarse  = 512/Nmode_p;
Nstart   = -256/Ncoarse+257
Nend     = Nstart + Nmode_p -1
randamp_ = randamp(Nstart:Nend, Nstart:Nend, 257-Nc_p+1:257);
randphs_ = randphs(Nstart:Nend, Nstart:Nend, 257-Nc_p+1:257);

clear subgaussseed512.matbin randamp randphs;
randamp = reshape(randamp_, Nmode_p*Nmode_p*Nc_p, 1);
randphs = reshape(randphs_, Nmode_p*Nmode_p*Nc_p, 1);
clear randamp_ randphs_;

%% for given cell (index for chosen cell: icc)
%%for idxcc = 1:Ncc
for idxcc = 1:1

  ic=icc(idxcc,1);
  jc=icc(idxcc,2);
  kc=icc(idxcc,3);
  
  ddir = ['ic' num2str(ic) '_jc' num2str(jc) '_kc' num2str(kc)]; 
  mkdir(ddir);

  %% Prepare base table for interpolation
  dc_mu_box  = reshape(deltasc_Ahn_cell_mu(idxcc,:,:),  Nsample,Nmu);
  db_mu_box  = reshape(deltasb_Ahn_cell_mu(idxcc,:,:),  Nsample,Nmu);
  Thc_mu_box = reshape(deltasThc_Ahn_cell_mu(idxcc,:,:),Nsample,Nmu);
  Thb_mu_box = reshape(deltasThb_Ahn_cell_mu(idxcc,:,:),Nsample,Nmu);
  T_mu_box   = reshape(deltasT_Ahn_cell_mu(idxcc,:,:),  Nsample,Nmu);

  %% For a given k, -mu case has its Real same as Imag of mu case,
  %%                         and its Imag same as Real of mu case.
  %% Switching Real and Imag is done easily by i*conj(complex_number).
  %% -- First, shift mu=[0,...,1] values to right.
  dc_mu_box (:,Nmu:2*Nmu-1) = dc_mu_box (:,:);
  db_mu_box (:,Nmu:2*Nmu-1) = db_mu_box (:,:);
  Thc_mu_box(:,Nmu:2*Nmu-1) = Thc_mu_box(:,:);
  Thb_mu_box(:,Nmu:2*Nmu-1) = Thb_mu_box(:,:);
  T_mu_box  (:,Nmu:2*Nmu-1) = T_mu_box  (:,:);
  %% -- Then, generate mu=[-1,...,0) values
  dc_mu_box (:,Nmu-1:-1:1) = conj(dc_mu_box (:,Nmu+1:2*Nmu-1))*i;
  db_mu_box (:,Nmu-1:-1:1) = conj(db_mu_box (:,Nmu+1:2*Nmu-1))*i;
  Thc_mu_box(:,Nmu-1:-1:1) = conj(Thc_mu_box(:,Nmu+1:2*Nmu-1))*i;
  Thb_mu_box(:,Nmu-1:-1:1) = conj(Thb_mu_box(:,Nmu+1:2*Nmu-1))*i;
  T_mu_box  (:,Nmu-1:-1:1) = conj(T_mu_box  (:,Nmu+1:2*Nmu-1))*i;
  
  %% Extend mu to cover full angle accordingly: muext=[-1,...,0,...,1]
  muext              = zeros(1,2*Nmu-1);
  muext(Nmu:2*Nmu-1) =  mu(1:Nmu);
  muext(Nmu-1:-1:1)  = -mu(2:Nmu);

  %% cosine(angle between k vector and V_cb=V_c-V_b).
  %% V_cb in this code is defined as "-V_bc=V_c-V_b" of Ahn (2016), unfortunately.
  %% Of course, transfer functions follow this (not Ahn 2016's) convention.
  %% See below for vb*_Ahn fields to see how streaming terms are added.
  costh_k_V = (V_cb_1_azend(ic,jc,kc)*k1_3D_p + V_cb_2_azend(ic,jc,kc)*k2_3D_p + V_cb_3_azend(ic,jc,kc)*k3_3D_p) /norm([V_cb_1_azend(ic,jc,kc) V_cb_2_azend(ic,jc,kc) V_cb_3_azend(ic,jc,kc)]) ./sqrt(ksq_p);


  %% Remark on ifftshif & ifftn ----------------------------------------------
  %% For odd #, ifftshift just works. The first array element in x direction 
  %% should correspond to axis monopole (kx=0), which ifftshift does.
  %% For even #, I have defined the domain as [-N/2,..,N/2-1] to use ifftshift.
  %% Example: a=[-3 -2 -1 0 1 2] --> ifftshift(a)=[0 1 2 -3 -2 -1] 
  %% Definition of ifftn clearly shows using the first element as the monopole.
  %% Next, the real-space fields on a cell!!! (ifftn)
  %% -------------------------------------------------------------------------



  %% =========== CDM density and position ======================== begin

  %% Matlab & Octave 2D interpolation!! --> generating k-space deltas 
  %% with array size Nmode_p, Nmode_p, Nmode_p.
  %% Matlab allows extrapolation only for 'spline' method.
  %% (costh_k_V and ksq_p have same array dimension, so interp2 
  %%  interprets these as scattered data points: see interp2 instruction)
  %% This is linear logarithmic interpolation along k, so the monopole
  %% term (k=0) may obtain inf or nan due to 0.5*log(ksq_p). 
  %% We will cure this by nullifying monopole anyway down below (**).
  dc_Ahn  = interp2(muext,log(ksampletab), dc_mu_box,  costh_k_V,0.5*log(ksq_p),interp2opt);  %% dc_Ahn still k-space values here.

  %% randomize, apply reality, and normalize
  dc_Ahn = rand_real_norm(dc_Ahn,Nmode_p,Nc_p,randamp,randphs,Vbox_p);
  %% CDM displacement vector, related to CDM density at 1st order.
  %% No need for above normalization because this is
  %% derived after above normalization on dc_Ahn.
  %% ------------- cpos1 ----------------------
  Psi1_Ahn                 = i*k1_3D_p./ksq_p.*dc_Ahn;
  Psi1_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  Psi1_Ahn                 = real(ifftn(ifftshift(Psi1_Ahn)));
  %% enzo position output is the combiation of the following steps:
  %%xCDM       = Psi1_Ahn + k1_3D_p/kunit_p*Lcell_p;                     %%(1)
  %%xCDM_enzo  = (xCDM + Lbox_p/2)/Lbox_p;                               %%(2)
  %%xCDM_enzo  = (Psi1_Ahn + k1_3D_p/kunit_p*Lcell_p + Lbox_p/2)/Lbox_p; %%(3)
  fout = fopen([ddir '/cpos1'], 'w');
  fwrite(fout, mod((Psi1_Ahn + (k1_3D_p/kunit_p+0.5)*Lcell_p + Lbox_p/2)/Lbox_p, 1), 'double');
  fclose(fout);
  xCDM_plane    =   Psi1_Ahn(:,:,1) + k1_3D_p(:,:,1)/kunit_p*Lcell_p + Lbox_p/2; %% for figure
  xCDM_ex_plane = 5*Psi1_Ahn(:,:,1) + k1_3D_p(:,:,1)/kunit_p*Lcell_p + Lbox_p/2; %% for figure, NOT REAL but to make more contrast in CDM position
  clear Psi1_Ahn  %% save memory

  %% ------------- cpos2 ----------------------
  Psi2_Ahn                 = i*k2_3D_p./ksq_p.*dc_Ahn;
  Psi2_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  Psi2_Ahn                 = real(ifftn(ifftshift(Psi2_Ahn)));
  fout = fopen([ddir '/cpos2'], 'w');
  fwrite(fout, mod((Psi2_Ahn + (k2_3D_p/kunit_p+0.5)*Lcell_p + Lbox_p/2)/Lbox_p, 1), 'double');
  fclose(fout);
  yCDM_plane    =   Psi2_Ahn(:,:,1) + k2_3D_p(:,:,1)/kunit_p*Lcell_p + Lbox_p/2; %% for figure
  yCDM_ex_plane = 5*Psi2_Ahn(:,:,1) + k2_3D_p(:,:,1)/kunit_p*Lcell_p + Lbox_p/2; %% for figure, NOT REAL but to make more contrast in CDM position
  clear Psi2_Ahn  %% save memory

  %% ------------- cpos3 ----------------------
  Psi3_Ahn                 = i*k3_3D_p./ksq_p.*dc_Ahn;
  Psi3_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  Psi3_Ahn                 = real(ifftn(ifftshift(Psi3_Ahn)));
  fout = fopen([ddir '/cpos3'], 'w');
  fwrite(fout, mod((Psi3_Ahn + (k3_3D_p/kunit_p+0.5)*Lcell_p + Lbox_p/2)/Lbox_p, 1), 'double');
  fclose(fout);
  clear Psi3_Ahn  %% save memory

  %% ------------- density ---------------------
  dc_Ahn = real(ifftn(ifftshift(dc_Ahn)));  %% just for debugging

  Zc    = reshape(dc_Ahn(:,:,1),Nmode_p,Nmode_p); %% for figure
  clear dc_Ahn  %% save memory
  %% =========== CDM density and position ======================== end



  %% =========== baryon density ================================== begin
  %% Matlab & Octave 2D interpolation!! --> generating k-space deltas 
  db_Ahn  = interp2(muext,log(ksampletab), db_mu_box,  costh_k_V,0.5*log(ksq_p),interp2opt);

  %% randomize, apply reality, and normalize
  db_Ahn = rand_real_norm(db_Ahn,Nmode_p,Nc_p,randamp,randphs,Vbox_p);

  %%%% If SPH particle is used, one can here get the particle positions 
  %%%% just the way CDM positions are calculated here.
  %% ------------- bpos1 ----------------------
  Psi1_Ahn                 = i*k1_3D_p./ksq_p.*db_Ahn;
  Psi1_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  Psi1_Ahn                 = real(ifftn(ifftshift(Psi1_Ahn)));
  %% enzo position output is the combiation of the following steps:
  %%xCDM       = Psi1_Ahn + k1_3D_p/kunit_p*Lcell_p;                     %%(1)
  %%xCDM_enzo  = (xCDM + Lbox_p/2)/Lbox_p;                               %%(2)
  %%xCDM_enzo  = (Psi1_Ahn + k1_3D_p/kunit_p*Lcell_p + Lbox_p/2)/Lbox_p; %%(3)
  fout = fopen([ddir '/bpos1'], 'w');
  fwrite(fout, mod((Psi1_Ahn + (k1_3D_p/kunit_p+0.5)*Lcell_p + Lbox_p/2)/Lbox_p, 1), 'double');
  fclose(fout);
  xbar_plane    =   Psi1_Ahn(:,:,1) + k1_3D_p(:,:,1)/kunit_p*Lcell_p + Lbox_p/2; %% for figure
  xbar_ex_plane = 5*Psi1_Ahn(:,:,1) + k1_3D_p(:,:,1)/kunit_p*Lcell_p + Lbox_p/2; %% for figure, NOT REAL but to make more contrast in CDM position
  clear Psi1_Ahn  %% save memory

  %% ------------- bpos2 ----------------------
  Psi2_Ahn                 = i*k2_3D_p./ksq_p.*db_Ahn;
  Psi2_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  Psi2_Ahn                 = real(ifftn(ifftshift(Psi2_Ahn)));
  fout = fopen([ddir '/bpos2'], 'w');
  fwrite(fout, mod((Psi2_Ahn + (k2_3D_p/kunit_p+0.5)*Lcell_p + Lbox_p/2)/Lbox_p, 1), 'double');
  fclose(fout);
  ybar_plane    =   Psi2_Ahn(:,:,1) + k2_3D_p(:,:,1)/kunit_p*Lcell_p + Lbox_p/2; %% for figure
  ybar_ex_plane = 5*Psi2_Ahn(:,:,1) + k2_3D_p(:,:,1)/kunit_p*Lcell_p + Lbox_p/2; %% for figure, NOT REAL but to make more contrast in CDM position
  clear Psi2_Ahn  %% save memory

  %% ------------- bpos3 ----------------------
  Psi3_Ahn                 = i*k3_3D_p./ksq_p.*db_Ahn;
  Psi3_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  Psi3_Ahn                 = real(ifftn(ifftshift(Psi3_Ahn)));
  fout = fopen([ddir '/bpos3'], 'w');
  fwrite(fout, mod((Psi3_Ahn + (k3_3D_p/kunit_p+0.5)*Lcell_p + Lbox_p/2)/Lbox_p, 1), 'double');
  fclose(fout);
  clear Psi3_Ahn  %% save memory

  %% ------------- density ---------------------
  db_Ahn = real(ifftn(ifftshift(db_Ahn)));  

  %% enzo baryon density output is the following:
  %%  db_enzo    = (db_Ahn+1)*fb
  fout = fopen([ddir '/db'], 'w');
  fwrite(fout, (db_Ahn+1)*fb, 'double');
  fclose(fout);

  Zb    = reshape(db_Ahn(:,:,1),Nmode_p,Nmode_p);
  clear db_Ahn  %% save memory
  %% =========== baryon density ================================== end



  %% =========== CDM velocity ==================================== begin
  %% Matlab & Octave 2D interpolation!! --> generating k-space deltas 
  Thc_Ahn = interp2(muext,log(ksampletab), Thc_mu_box, costh_k_V,0.5*log(ksq_p),interp2opt);

  %% randomize, apply reality, and normalize
  Thc_Ahn = rand_real_norm(Thc_Ahn,Nmode_p,Nc_p,randamp,randphs,Vbox_p);

  %% ------------- vc1 ----------------------
  vc1_Ahn(:,:,:)          = -i*azend*k1_3D_p./ksq_p.*Thc_Ahn(:,:,:);
  vc1_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  vc1_Ahn                 = real(ifftn(ifftshift(vc1_Ahn)));
  %% enzo velocity output is the following:
  %%vc1_enzo = vc1_Ahn * MpcMyr_2_kms * 1e5 /VelocityUnits;
  fout = fopen([ddir '/vc1'], 'w');
  fwrite(fout, vc1_Ahn*MpcMyr_2_kms*1e5/VelocityUnits, 'double');
  fclose(fout);
  Vc1 = reshape(vc1_Ahn(:,:,1) *MpcMyr_2_kms, Nmode_p, Nmode_p); %% for figure
  clear vc1_Ahn  %% save memory

  %% ------------- vc2 ----------------------
  vc2_Ahn(:,:,:)          = -i*azend*k2_3D_p./ksq_p.*Thc_Ahn(:,:,:);
  vc2_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  vc2_Ahn                 = real(ifftn(ifftshift(vc2_Ahn)));
  fout = fopen([ddir '/vc2'], 'w');
  fwrite(fout, vc2_Ahn*MpcMyr_2_kms*1e5/VelocityUnits, 'double');
  fclose(fout);
  Vc2 = reshape(vc2_Ahn(:,:,1) *MpcMyr_2_kms, Nmode_p, Nmode_p); %% for figure
  clear vc2_Ahn  %% save memory

  %% ------------- vc3 ----------------------
  vc3_Ahn(:,:,:)          = -i*azend*k3_3D_p./ksq_p.*Thc_Ahn(:,:,:);
  vc3_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  vc3_Ahn                 = real(ifftn(ifftshift(vc3_Ahn)));
  fout = fopen([ddir '/vc3'], 'w');
  fwrite(fout, vc3_Ahn*MpcMyr_2_kms*1e5/VelocityUnits, 'double');
  fclose(fout);
  Vc3 = reshape(vc3_Ahn(:,:,1) *MpcMyr_2_kms, Nmode_p, Nmode_p); %% for figure
  clear vc3_Ahn  %% save memory

  %% ------------- velocity divergence ---------------------
  Thc_Ahn = real(ifftn(ifftshift(Thc_Ahn)));  

  ZThc = reshape(Thc_Ahn(:,:,1),Nmode_p,Nmode_p); %% for figure
  clear Thc_Ahn  %% save memory
  %% =========== CDM velocity ==================================== end


  %% =========== baryon velocity ==================================== begin
  %% Matlab & Octave 2D interpolation!! --> generating k-space deltas 
  Thb_Ahn = interp2(muext,log(ksampletab), Thb_mu_box, costh_k_V,0.5*log(ksq_p),interp2opt);

  %% randomize, apply reality, and normalize
  Thb_Ahn = rand_real_norm(Thb_Ahn,Nmode_p,Nc_p,randamp,randphs,Vbox_p);

  %% ------------- vb1 ----------------------
  vb1_Ahn(:,:,:)          = -i*azend*k1_3D_p./ksq_p.*Thb_Ahn(:,:,:);
  vb1_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  vb1_Ahn                 = real(ifftn(ifftshift(vb1_Ahn)));
  %% add streaming velocity (V_cb = Vc - Vb)
  vb1_Ahn                 = vb1_Ahn - V_cb_1_azend(ic,jc,kc); 
  %% enzo velocity output is the following:
  %%vb1_enzo = vb1_Ahn * MpcMyr_2_kms * 1e5 /VelocityUnits;
  fout = fopen([ddir '/vb1'], 'w');
  fwrite(fout, vb1_Ahn*MpcMyr_2_kms*1e5/VelocityUnits, 'double');
  fclose(fout);

  %% memory-saving way of calculating sp_Etot_enzo (**--1--**)
  sp_Etot_enzo = 1/2*(vb1_Ahn*MpcMyr_2_kms*1e5/VelocityUnits).^2; 

  Vb1 = reshape(vb1_Ahn(:,:,1) *MpcMyr_2_kms, Nmode_p, Nmode_p); %% for figure
  clear vb1_Ahn  %% save memory

  %% ------------- vb2 ----------------------
  vb2_Ahn(:,:,:)          = -i*azend*k2_3D_p./ksq_p.*Thb_Ahn(:,:,:);
  vb2_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  vb2_Ahn                 = real(ifftn(ifftshift(vb2_Ahn)));
  %% add streaming velocity (V_cb = Vc - Vb)
  vb2_Ahn                 = vb2_Ahn - V_cb_2_azend(ic,jc,kc); 
  fout = fopen([ddir '/vb2'], 'w');
  fwrite(fout, vb2_Ahn*MpcMyr_2_kms*1e5/VelocityUnits, 'double');
  fclose(fout);

  %% memory-saving way of calculating sp_Etot_enzo (**--2--**)
  sp_Etot_enzo = sp_Etot_enzo + 1/2*(vb2_Ahn*MpcMyr_2_kms*1e5/VelocityUnits).^2; 

  Vb2 = reshape(vb2_Ahn(:,:,1) *MpcMyr_2_kms, Nmode_p, Nmode_p); %% for figure
  clear vb2_Ahn  %% save memory

  %% ------------- vb3 ----------------------
  vb3_Ahn(:,:,:)          = -i*azend*k3_3D_p./ksq_p.*Thb_Ahn(:,:,:);
  vb3_Ahn(Nc_p,Nc_p,Nc_p) = complex(0);  %% fixing nan or inf monopole
  vb3_Ahn                 = real(ifftn(ifftshift(vb3_Ahn)));
  %% add streaming velocity (V_cb = Vc - Vb)
  vb3_Ahn                 = vb3_Ahn - V_cb_3_azend(ic,jc,kc); 
  fout = fopen([ddir '/vb3'], 'w');
  fwrite(fout, vb3_Ahn*MpcMyr_2_kms*1e5/VelocityUnits, 'double');
  fclose(fout);

  %% memory-saving way of calculating sp_Etot_enzo (**--3--**)
  sp_Etot_enzo = sp_Etot_enzo + 1/2*(vb3_Ahn*MpcMyr_2_kms*1e5/VelocityUnits).^2; 

  Vb3 = reshape(vb3_Ahn(:,:,1) *MpcMyr_2_kms, Nmode_p, Nmode_p); %% for figure
  clear vb3_Ahn  %% save memory

  %% ------------- velocity divergence ---------------------
  Thb_Ahn = real(ifftn(ifftshift(Thb_Ahn)));  

  ZThb = reshape(Thb_Ahn(:,:,1),Nmode_p,Nmode_p); %% for figure
  clear Thb_Ahn  %% save memory
  %% =========== baryon velocity ==================================== end


  %% =========== baryon temperature, energies ======================= begin
  %% Matlab & Octave 2D interpolation!! --> generating k-space deltas 
  dT_Ahn  = interp2(muext,log(ksampletab), T_mu_box,  costh_k_V,0.5*log(ksq_p),interp2opt);

  %% randomize, apply reality, and normalize
  dT_Ahn = rand_real_norm(dT_Ahn,Nmode_p,Nc_p,randamp,randphs,Vbox_p);

  %% ------------- temperature, energies  ---------------------
  dT_Ahn = real(ifftn(ifftshift(dT_Ahn)));  


  %% Mean IGM temperature fit from Tseliakhovich & Hirata
  aa1  = 1/119
  aa2  = 1/115
  Tz    = TCMB0/af /(1+af/aa1/(1+(aa2/af)^1.5));  %% in K, global average temperature
  Tz    = Tz*(1+DT3D_azend(ic,jc,kc)); %% local(cell) average temperature
  
  %% specific thermal energy for monatomic gas (H+He), in units of VelocityUnits^2 : sp_Eth_enzo
  %%Tcell = (dT_Ahn+1)*Tz;  %% in K
  %%sp_Eth_enzo  = 3/2*kb*Tcell /(mmw*mH) /VelocityUnits^2;  %% see Enzo paper(2014) eq. 7.
  fout = fopen([ddir '/etherm'], 'w');
  fwrite(fout, 3/2*kb*(dT_Ahn+1)*Tz /(mmw*mH) /VelocityUnits^2, 'double');
  fclose(fout);

  %% Zeth in erg (thermal energy per baryon)
  Zeth = reshape(3/2*kb*(dT_Ahn(:,:,1)+1)*Tz/(mmw*mH),Nmode_p,Nmode_p); %% for figure

  %% Ztemp in K
  Ztemp = reshape((dT_Ahn(:,:,1)+1)*Tz,Nmode_p,Nmode_p); %% for figure


  %% specific total energy for monatomic gas (H+He), in units of VelocityUnits^2 :   sp_Etot_enzo
  %% Currently sp_Etot_enzo does not include magnetic contribution, but in principle it should.
  %% memory-saving way of calculating sp_Etot_enzo (**--4--**)
  sp_Etot_enzo = sp_Etot_enzo + 3/2*kb*(dT_Ahn+1)*Tz /(mmw*mH) /VelocityUnits^2;
  
  fout = fopen([ddir '/etot'], 'w');
  fwrite(fout, sp_Etot_enzo, 'double');
  fclose(fout);

  %% Zetot in erg (total energy per baryon)
  Zetot = reshape(sp_Etot_enzo(:,:,1)*VelocityUnits^2,Nmode_p,Nmode_p); %% for figure

  clear dT_Ahn sp_Etot_enzo
  %% =========== baryon temperature, energies ======================= begin

  %% Save some memory
  clear costh_k_V 
  %clear randamp randphs k1_3D_p k2_3D_p k3_3D_p ksq_p

  %% To run on HPC, just dump figure-useful data and skip the following.
  save('-mat-binary', [ddir '/4fig.matbin'], 'xCDM_plane', 'xCDM_ex_plane', 'yCDM_plane', 'yCDM_ex_plane', 'Zc', 'xbar_plane', 'xbar_ex_plane', 'ybar_plane', 'ybar_ex_plane', 'Zb', 'Vc1', 'Vc2', 'Vc3', 'ZThc', 'Vb1', 'Vb2', 'Vb3', 'ZThb', 'Zeth', 'Ztemp', 'Zetot') %%octave
  %%save([ddir '/4fig.matbin'], 'xCDM_plane', 'xCDM_ex_plane', 'yCDM_plane', 'yCDM_ex_plane', 'Zc', 'xbar_plane', 'xbar_ex_plane', 'ybar_plane', 'ybar_ex_plane', 'Zb', 'Vc1', 'Vc2', 'Vc3', 'ZThc', 'Vb1', 'Vb2', 'Vb3', 'ZThb', 'Zeth', 'Ztemp', 'Zetot', '-v6') %%matlab

end

