%% Integrate evolution equation (eq. 11 of A16) and dump its output
%% The output name will bear the cell index

%% Loop over different k values ----------------------------------------begin
Nsample         = 100; %% more patience needed for larger Nsample
%% Uniform log(k) sampling
log10ksampletab = linspace(log10(1),log10(14000),Nsample)';
ksampletab      = 10.^log10ksampletab;

%% directory for main output (fluctuation)
TFdir = [setupdir '/deltas'];
if ~exist(TFdir)
  mkdir(TFdir);
end

TFTHdir = [setupdir '/deltas_TH'];
if THflag
  if ~exist(TFTHdir)
    mkdir(TFTHdir);
  end
end

%% high-k mode fluctuations at z=zi.
delta_c_k = interp1(kktab, Dc_zi,  ksampletab, 'spline');
theta_c_k = interp1(kktab, THc_zi, ksampletab, 'spline');
delta_b_k = interp1(kktab, Db_zi,  ksampletab, 'spline');
theta_b_k = interp1(kktab, THb_zi, ksampletab, 'spline');
delta_T_k = interp1(kktab, DT_zi,  ksampletab, 'spline');

%% Time integration interval for ode45
azbegin = ai;    %% z=1000
azend   = 1/(1+zzend);
zzbegin = 1/azbegin-1;
zzend   = 1/azend  -1;

if matlabflag
  save([setupdir '/zz.dat'], 'zzbegin','zzend', '-ascii');
else
  save('-ascii', [setupdir '/zz.dat'], 'zzbegin','zzend');
end

ic = icc1;
jc = icc2;
kc = icc3;

%% Main output: fluctuation at zzend as a function of k.
stroutD =   [TFdir '/Deltas_1Dmu_ic' num2str(ic) '_jc' num2str(jc) '_kc' num2str(kc) '-muhalf.matbin'];
strouth5D = [TFdir '/Deltas_1Dmu_ic' num2str(ic) '_jc' num2str(jc) '_kc' num2str(kc) '-muhalf.h5'];

%% These are complex values.
%% for a given patch(icc).
deltasc   = zeros(Nsample, Nmu); 
deltasb   = zeros(Nsample, Nmu); 
deltasThc = zeros(Nsample, Nmu); 
deltasThb = zeros(Nsample, Nmu);
deltasT   = zeros(Nsample, Nmu);

if THflag
  strTHoutD   = [TFTHdir '/Deltas_TH_1Dmu_ic' num2str(ic) '_jc' num2str(jc) '_kc' num2str(kc) '-muhalf.matbin'];
  strTHouth5D = [TFTHdir '/Deltas_TH_1Dmu_ic' num2str(ic) '_jc' num2str(jc) '_kc' num2str(kc) '-muhalf.h5'];

  deltasc_TH    = zeros(Nsample, Nmu);
  deltasb_TH    = zeros(Nsample, Nmu); 
  deltasThc_TH  = zeros(Nsample, Nmu); 
  deltasThb_TH  = zeros(Nsample, Nmu);
  deltasT_TH    = zeros(Nsample, Nmu);
end

if (~exist(stroutD) || OWRTflag)  %% big if beginning
  Deltagro_p    = Deltagro(ic, jc, kc);
  Deltadec_p    = Deltadec(ic, jc, kc);
  Deltacom_p    = Deltacom(ic, jc, kc);
  Deltastr_p    = Deltastr(ic, jc, kc);
  Thc_i         = Theta_c (ic, jc, kc);
  Thb_i         = Theta_b (ic, jc, kc);
  signDT        = sign(DTA3D(ic, jc, kc));
  alpha         = log10(DTB3D(ic,jc,kc)/DTA3D(ic,jc,kc))*alphaYcoeff;
  coeff_Delta_T = abs(DTA3D(ic,jc,kc))^powDTA /abs(DTB3D(ic,jc,kc))^powDTB; %% 10^-Y, Y defined in eq. 30 of A16
  rV_i          = Vcb     (ic, jc, kc);

  for isample=1:Nsample  %% this loop takes a long while!!
    disp([num2str(isample) 'th wavenumber out of ' num2str(Nsample) ' is being handled.']);
    ksample    = ksampletab(isample);

    %% Integrate evolution equation by TH, just for comparison.
    x0 = [delta_c_k(isample); theta_c_k(isample); delta_b_k(isample); theta_b_k(isample); delta_c_k(isample); theta_c_k(isample); delta_b_k(isample); theta_b_k(isample); delta_T_k(isample); delta_T_k(isample)]/sqrt(2);

    for imu=1:Nmu
      disp(['* ' num2str(imu) 'th angle outta ' num2str(Nmu) ' is being handled.']);
      costh = mu(imu);

      %% A16 ================
      options = odeset('RelTol',1e-4,'AbsTol',0.01*min(abs(x0)));
      [azode, deltaode] = ode45(@f,[azbegin,azend],x0,options);
      deltasAhn  = interp1(azode, deltaode, azend, 'linear', 'extrap');
        
      deltasc  (isample, imu) = deltasAhn(1)+i*deltasAhn(5);
      deltasb  (isample, imu) = deltasAhn(3)+i*deltasAhn(7);
      deltasThc(isample, imu) = deltasAhn(2)+i*deltasAhn(6);
      deltasThb(isample, imu) = deltasAhn(4)+i*deltasAhn(8);
      deltasT  (isample, imu) = deltasAhn(9)+i*deltasAhn(10);

      if (THflag && (~exist(strTHoutD) || OWRTflag))
	%% TH ===================
	options = odeset('RelTol',1e-4,'AbsTol',0.01*min(abs(x0)));
	[azode, deltaode] = ode45(@fTH,[azbegin,azend],x0,options);
	deltasTH  = interp1(azode, deltaode, azend, 'linear', 'extrap');
        
	deltasc_TH  (isample, imu) = deltasTH(1)+i*deltasTH(5);
	deltasb_TH  (isample, imu) = deltasTH(3)+i*deltasTH(7);
	deltasThc_TH(isample, imu) = deltasTH(2)+i*deltasTH(6);
	deltasThb_TH(isample, imu) = deltasTH(4)+i*deltasTH(8);
	deltasT_TH  (isample, imu) = deltasTH(9)+i*deltasTH(10);
      end
    end
  end 
  
  %% Save files: Similar to transfer function output from CAMB.
  %% Save also in hdf5, to make bccomics.m ported to other language 
  %% & optimized & improved.
  %% '-v7.3' makes simple hdf5 file in Matlab, and compressed.
  %% '-hdf5' makes simple hdf5 file in octave, likely uncompressed.
  %% As intended hdf5 file generated either way contains identical
  %% data and is portable. 
  %% BUT,...,
  %% attributes are different, so loading hdf5 file gets sligtly messy for
  %% coding and matlab binary is thus preferred for matlab/octave code.
  %%
  %% When loading hdf5 file in Matlab:
  %%  (1) Matlab-saved hdf5: ksampletab=h5read(strouth5D, '/ksampletab');
  %%                         deltasc   =h5read(strouth5D, '/deltasc');
  %%                         ...
  %%  (2) Octave-saved hdf5: ksampletab=h5read(strouth5D, '/ksampletab/value');
  %%                         deltasc   =h5read(strouth5D, '/deltasc/value');
  %%                         ...
  %% When loading hdf5 file in Octave:
  %%  (1) Matlab-saved hdf5: load('-hdf5', strouth5D, 'ksampletab', 'deltasc', ...);
  %%  (2) Octave-saved hdf5: load('-hdf5', strouth5D, 'ksampletab', 'deltasc', ...);
  %%
  %% So, loading from Matlab (or other language) needs to detect whether the
  %% hdf5 file was made by Octave or Matlab, to handle the slightly different
  %% attribute conventions. Loading from Octave gets much simpler: identical
  %% syntax is needed. 
  if matlabflag
    %% to matlab binary format
    save(stroutD,     'ksampletab', 'deltasc',    'deltasb',    'deltasThc',    'deltasThb',    'deltasT',    '-v6');
    if THflag
      save(strTHoutD, 'ksampletab', 'deltasc_TH', 'deltasb_TH', 'deltasThc_TH', 'deltasThb_TH', 'deltasT_TH', '-v6');
    end

    %% to hdf5 format
    save(strouth5D,     'ksampletab', 'deltasc',    'deltasb',    'deltasThc',    'deltasThb',    'deltasT',    '-v7.3');
    if THflag
      save(strTHouth5D, 'ksampletab', 'deltasc_TH', 'deltasb_TH', 'deltasThc_TH', 'deltasThb_TH', 'deltasT_TH', '-v7.3');
    end
  else
    %% to matlab binary format
    save('-mat-binary',   stroutD,   'ksampletab', 'deltasc',    'deltasb',    'deltasThc',    'deltasThb',    'deltasT'   );
    if THflag
      save('-mat-binary', strTHoutD, 'ksampletab', 'deltasc_TH', 'deltasb_TH', 'deltasThc_TH', 'deltasThb_TH', 'deltasT_TH');
    end

    %% to hdf5 format
    save('-hdf5',   strouth5D,   'ksampletab', 'deltasc',    'deltasb',    'deltasThc',    'deltasThb',    'deltasT'   );
    if THflag
      save('-hdf5', strTHouth5D, 'ksampletab', 'deltasc_TH', 'deltasb_TH', 'deltasThc_TH', 'deltasThb_TH', 'deltasT_TH');
    end
  end
end  %% big if end

