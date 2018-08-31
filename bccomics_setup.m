%%
%% BCCOMICS setup: Sets up patch values at recombination.
%%                 This is the first one of the two main programs.
%% 
%%
%% Author: Kyungjin Ahn
%%
%% This MATLAB(R) / GNU Octave code is freely distributed, and you are
%% free to modify it or port it into other languages. BCCOMICS is under
%% an absolutely no-warranty condition. It is assumed that you consent
%% to one condition: when you get scientific results using BCCOMICS
%% and publish them, you need to cite these two papers:
%% ---------
%% Ahn 2016, ApJ 830:68 (A16)
%% Ahn & Smith 2018, arXiv:1807.04063 (AS18, to be replaced if published)
%% ---------
%%
%% Other references:
%%   Ma & Bertschinger 1995, ApJ 455, 7 (MB)
%%   Naoz & Barkana 2005, MNRAS 362, 1047 (NB)
%%   Tseliakhovich & Hirata 2010, PRD, 82, 083520 (TH)
%%
%%
%% What it does: This code reads in (preferentially) CAMB-generated
%%               transfer functions at z=1000 (and one other snapshot at
%%               z=800), and generates 3D Eulerian fields of fluctuations.
%%               The cell size of these fields are chosen to be 4 comoving
%%               Mpc, which is about the correlation length of V_bc, but
%%               you are free to change this size depending on the physics
%%               you are interested in.
%%
%%               User is needed to supply parameters in params.m,
%%               CAMB transfer function outputs, and recfast output.
%%               CAMB parameters should be reflected in a .m file, as in
%%               LCDM.m. The source code comes with pre-calculated CAMB
%%               outputs (with input parameter files) under
%%               CAMB_for_mode_finding/, and recfast output 'output_recfast'.
%%
%%               3D fields are generated by FFTing k-space fields, which
%%               makes the box-size effect apparent. MUSIC (Hahn & Abel)
%%               does a better job of minimizing the box-size effect but
%%               we do not implement their method yet.
%%
%%               By combining fields at z=1000 and z=800, we extract 4
%%               normal modes - growing, decaying, compensated, streaming -
%%               at z=1000. This is a necessary bit for evaluating how
%%               patch values are evolved, which then need to be used in
%%               evolving small-scale fluctuations under a patch
%%               environment.
%%               
%%
%% Some details:
%% ----------
%% Evolve_DeltaT_accurate.m, fdDTda.m, Check_mu_symmetry.m are NOT used.
%% These are just for reference and possible future update.
%%
%% Capital lettered (Delta, Theta, ..) matter quantities describe patch
%% quantities. They are evolved with linear growth factors: constant for the 
%% compensated mode and numerically calculated ones for growing, decaying, 
%% and streaming modes.
%%
%% Small lettered (delta, theta, ...) matter quantities describe to-be-impacted 
%% high-k values. Code uses only 1/2 of azimuths (costh below) for faster 
%% calculation. The power spectrum is simply identical for given theta and
%% -theta.
%% 
%% After z=1000 radiation fluctuation is neglected, while its average quantity
%% is respected in the Hubble constant, Omega_matter, and growth factors.
%% The long-term advection is ignored: the growth is calculated but the Eulerian
%% grid is treated as if it is Lagrangian.
%%
%% Radiation fluctuation after z=1000 is NOT considered for evolution of
%% Delta_T. Delta_T uses the fitting formula (eq. 30 of A16), which is
%% a sort of adiabatically determined one. This is OK because when radiation
%% fluctuation is important, Delta_T is quite small. Nevertheless, we may get 
%% a more accurate result if radiation fluctuation is carefully considered.
%% Evolve_DeltaT_accurate.m shows how one can (in principle) do this.
%%

more off; %% enables to see progress

%% Detect which is running: octave or matlab?
if (exist('OCTAVE_VERSION','builtin'))
  matlabflag=false;
else
  matlabflag=true;
end

disp('----------------Initializing----------------');
%% Read in essential parameters
params;  %%==== script ==================
%% Define some box-related quantities
box_init;  %%==== script ==================
if (mod(Ncell,2)==0)
  disp('Choose an odd number to make a patch 4 Mpc in size');
  return;
end
if (Lcell ~= 4)
  disp('Make Lcell as close as to 4 Mpc; otherwise DeltaT will gain some error.');
  disp('Will proceed anyway, but you have been warned...');
  disp(' --- Hit any key to proceed, or Ctrl+C to stop --- ');
  pause;
end

%% Some old versions of gnu octave has buggy ifftshift routine, so for
%% octave version older than 4.0.1, just use working one under the provided
%% directory. In case statistics package (for raylrnd) is not installed,
%% use provided statistics package. In case ode45 is not available, use
%% provided ODE package. All this can be avoided by upgrading to recent
%% octave version and installing octave-statistics package.
if ~matlabflag
  if compare_versions(OCTAVE_VERSION,'4.0.1','<')
    %% Messages "warning: function * shadows ..." should be welcomed.
    addpath('mfiles_for_octave'); 
  end
  if ~exist('raylrnd')
    addpath('statistics-1.3.0/inst');
  end
  if ~exist('ode45')
    addpath('odepkg-0.8.5');
  end
end

%% Create directory to dump outputs
if ~exist(outputdir)
  mkdir(outputdir);
end

%% take time unit to be 10^6 year, and length unit to be Mpc.
global mH kb MpcMyr_2_kms;
%% Read in constants in cgs unit and conversion factors.
Consts_Conversions;  %%==== script ==================

%% cosmological parameters
global H0 Om0 Omr0 TCMB0 OmLambda0;
global tgamma;
%% read in cosmological parameters for background LambdaCDM universe
%% -- CAREFUL: Numerical values need to match CAMB input !!!!!!!!!!
run(Cosmology);  %%==== script ==================

%% Working at only very high z, so below is OK for now.
global fb fc;
fb = ombh2/(ombh2+omch2); %% baryon/matter fraction
fc = omch2/(ombh2+omch2); %% CDM/matter fraction

%% Using fit by TH (Eq. 2) for global baryon temperature.
%% Do NOT change zi below.
%% Also the initial transfer function is loaded here.
global ai aa1 aa2;
zi      = 1000;  %% our choice for beginning redshift (soon after recombination)
ai      = 1/(1+zi);
Hzi     = H0*sqrt(Om0*(1+zi)^3 + Omr0*(1+zi)^4); %% initil Hubble in Myr^-1 unit
aa1     = 1/119; %% aa1 & aa2 under Eq. 2 in TH
aa2     = 1/115;
Tbzi    = TCMB0/ai /(1+ai/aa1/(1+(aa2/ai)^1.5)); %% baryon temperature fit in NB
cszi    = sqrt((5/3)*kb*Tbzi/(1.22*mH)) * 1e-5;  %% sound speed in km/s
Tgammai = TCMB0*(1+zi);  %% CMB temperature at z=1000

%% Fluctuations and power spectra at zi ----------------------- begin
TF_zi = load([TFstr1 num2str(zi) TFstr2]); %% transfer function at zi
kktab = TF_zi(:,1)*h;  %% k, in Mpc^-1 unit
%% Primordial power spectrum: See IV.A in CAMB.pdf from http://cosmologist.info/notes
lnPstab     = log(As)+(ns-1)*log(kktab/k0)+nrun/2*(log(kktab/k0)).^2+nrunrun/6*(log(kktab/k0)).^3;
%% powe spectrum without TF^2, where TF is the CAMB transfer function output
%% Refer to Transfer_GetMatterPowerData subroutine in CAMB
PS_wo_TFtab_ = exp(lnPstab) .* kktab *2*pi^2 * h^3; %% if TF^2 multiplied, in h^-3 Mpc^3 unit
PS_wo_TFtab  = PS_wo_TFtab_ * h^-3;  %% if TF^2 multiplied, in Mpc^3 unit

Pkc_zi   = PS_wo_TFtab .* TF_zi(:,2).^2;  %% Mpc^3 unit, CDM
Pkb_zi   = PS_wo_TFtab .* TF_zi(:,3).^2;  %% Mpc^3 unit, baryon
Pkr_zi   = PS_wo_TFtab .* TF_zi(:,4).^2;  %% Mpc^3 unit, radiation
PkTHc_zi = PS_wo_TFtab .* TF_zi(:,11).^2;  %% Mpc^3 unit, CDM vel divergence
PkTHb_zi = PS_wo_TFtab .* TF_zi(:,12).^2;  %% Mpc^3 unit, baryon vel divergence
PkVcb_zi = PS_wo_TFtab .* TF_zi(:,13).^2;  %% Mpc^3 unit, Vc-Vb

%% perturbation -- see CAMB Readme for meaning of columns
Dc_zi  =  sqrt(Pkc_zi)   .*sign(TF_zi(:,2)); %% Mpc^(3/2) unit
Db_zi  =  sqrt(Pkb_zi)   .*sign(TF_zi(:,3)); %% Mpc^(3/2) unit
Dr_zi  =  sqrt(Pkr_zi)   .*sign(TF_zi(:,4)); %% Mpc^(3/2) unit
THc_zi = -sqrt(PkTHc_zi) .*sign(TF_zi(:,11))*Hzi; %% Mpc^(3/2) Myr^-1 unit
THb_zi = -sqrt(PkTHb_zi) .*sign(TF_zi(:,12))*Hzi; %% Mpc^(3/2) Myr^-1 unit
Vcb_zi = -sqrt(PkVcb_zi) .*sign(TF_zi(:,13))*c_inkms/MpcMyr_2_kms; %% Mpc^(3/2) Mpc Myr^-1 unit
%% sanity check of sign: Try plots for confirmation if wanted...
Vc_zi  = -sqrt(PkTHc_zi) .*sign(TF_zi(:,11))*ai*Hzi./kktab;
Vb_zi  = -sqrt(PkTHb_zi) .*sign(TF_zi(:,12))*ai*Hzi./kktab;
% semilogx(kktab, THc_zi); %% should be negative, because THc = -dDc/dt
% semilogx(kktab, (Vc_zi-Vb_zi)./Vcb_zi); %% should be 1, NOT -1.
%% Fluctuations and power spectra at zi ----------------------- end

%% Use recfast output for z(redshift)-xe(global ionized fraction) table.
%% Table can be non-recfast as long as you trust it.
%% CAREFUL: for efficient interpolation at any given redshift, the redshift
%% interval MUST be uniform.
global zrecf xerecf dzrecf zrecf1; %% do not bother naming convention
zxe    = load(zxestr);
%% Well recfast is preferred and thus the name of variables...
zrecf  = zxe(:,1);
xerecf = zxe(:,2);
xei    = interp1(zrecf, xerecf, zi); %% xe(zi)
dzrecf = zrecf(1)-zrecf(2);
zrecf1 = zrecf(1);
%% a bit of safeguard for non-uniform-z recfast table
if (dzrecf ~= zrecf(9)-zrecf(10))
  disp('Recfast output is not uniform in z. Quitting.');
  return;
end
%% table should be in descending order in z
if (zrecf(1) < zrecf(2))
  disp('z-xe table should have decreasing z');
  return;
end

%% Temporal evolution of growing, decaying, and streaming modes ---------------- begin
%%
%% Radiation components (photon + neutrino) make these modes NOT follow the simple
%% power laws (\propto a, a^-1.5, a^-0.5 respectively for density). Therefore,
%% numerical integration should be done to find the correct mode evolution &
%% mode extraction.
%%
%% Neutrinos are all assumed relativistic throughout, so massive neutrino
%% effect is NOT reflected in Omega_matter and H(z). This should not be
%% a problem for z>~100 though, as long as m_neutrino <~ 0.05 eV.
%% Possible future modification point in e.g. 
%%
%% For growing mode, start integration from super-high z, which is radiation
%% dominated, where a simple asymptote exists.
%%
%% For decaying and streaming modes, see comments inside Get_growth.m.
%% Actual calculation of these modes differ from Appendix A of A16: now
%% the asymptote is much more accurate than A16, and the quantitative
%% value of the decaying mode has changed substantially.
%%
%% Normalization convention follows that of A16: D=1 @ z=1000 
%% (see Appendix A of A16).
%%
%% Resulting tables are saved in [outputdir '/a_growth.dat'] for record keeping.
global Dplus_grow Dplus_decay Dminus_stream dDplus_grow_da dDplus_decay_da dDminus_stream_da azz log10az_min dlog10az;

Get_growth;  %%==== script ==================
%% Temporal evolution of growing, decaying, and streaming modes ---------------- end

%%%%%%%% mode extraction and, if wanted, some plotting ----------------------- begin
Extract_modes;  %%==== script ==================

%% --- plot ---
if plotflag
  Plot_modes;  %%==== script ==================
end

%% dump modes
fout  = fopen([outputdir '/k_gro_dec_com_str.dat'],'w');
mdata = [kktab Deltagro_k Deltadec_k Deltacom_k Deltastr_k];
fprintf(fout,'%14.7e %14.7e %14.7e %14.7e %14.7e\n', mdata'); %%'
fclose(fout);
%%%%%%%% mode extraction and, if wanted, some plotting ------------------------- end

%% At z=1000, get baryon temperature fluctuation DT_zi
Initialize_DeltaT;  %%==== script ==================

disp('----------------gaussian seed being read-in (or generated)----------------');
pause(1);
%%%%%% Get 3D spatial fluctuatons in the big box ------------------------------ begin
%% 2 Gaussian random number sets into a complex number field.
%% Generate AND use file only when there does NOT exist the randome seed file.
fgaussstr = [outputdir '/gaussseed.matbin'];
if (~exist(fgaussstr))
  Nreallization = 12000000;

  gauss1 = normrnd(0,1,[Nreallization,1]);
  gauss2 = normrnd(0,1,[Nreallization,1]);
  gauss  = gauss1+i*gauss2;

  %% Save gaussian ramdom seed, in complex format.
  %% For compatibility with older octave versions, matlab binary should be in v6.
  if (matlabflag)
    save(fgaussstr, 'gauss', '-v6');
  else
    save('-mat-binary', fgaussstr, 'gauss'); %% -mat-binary = -v6 in octave
  end
else %% load preexisting seed
  if matlabflag
    load(fgaussstr, '-mat', 'gauss')  %% matlab knows about binary version
  else
    load('-mat-binary', fgaussstr, 'gauss')
  end
end

%% 3D gaussian random number (G1+iG2)
gauss3D = reshape(gauss(1:Nmode^3),Nmode,Nmode,Nmode);

disp('----------------Generating real-space 3D fields----------------');
%% Random-number-seeding and FFTing to generate 3D fields of patches at z=zi=1000
Get_patches_3D_zi;  %%==== script ==================

azbegin = ai;    %% z=1000
azend   = 1/(1+zzend);

%% By using modes generate 3D fields of patches at z=zzend.
%% Only for DeltaT, fitting formula is used (Get_DeltaT_fit used inside the script)
global beta gamma;
global signDT alpha coeff_Delta_T;
Get_patches_3D_zend;  %%==== script ==================

%% Choose a patch at z=zi=1000. Cherry picking!! 
%% Right now, variances in (1) CDM density, (2) V_cb.
Choose_patch;  %%==== script ==================

%% master equation for high k modes:
%% *_p are the 4 modes at a chosen patch
global ksample costh Deltagro_p Deltadec_p Deltacom_p Deltastr_p;

%% for mu(=cosine of angle between Vcb and k) loop
dmu = 0.05;
mu  = 0:dmu:1; %% Use symmetry of P(k,mu) about mu=0 to save calculation time.
Nmu = length(mu);

if matlabflag
  save([outputdir '/mu.dat'],'mu','-ascii');
else
  save('-ascii',[outputdir '/mu.dat'],'mu');
end

disp('----------------Integrating----------------');
%% Integrate evolution ODE equation, eq. 11 of A16.
%% If wanted(THflag), evolution equation by TH is also solved for reference.
%% Also dump fluctuations at zzend, which will be used by bccomics.m
global Thc_i Thb_i rV_i;
return;
Integrate_evolODE;  %%==== script ==================
