%% prepare for initial consitions for enzo, dumping units too.

%% units are all in cgs (from enzo CosmologyGetUnits.C)
%% enzo length unit is for anything in proper distance centimeter. So if one has something in comoving distance Mpc, one just needs to divide it by box size in units of comoving Mpc.
DensityUnits  = 1.8788e-29*Om0*h^2*(1+zf)^3;
VelocityUnits = 1.22475e7*Lbox_p_inMpch*sqrt(Om0)*sqrt(1+zf);
SpecificEnergyUnits = VelocityUnits^2; %% specific energy = energy/mass 

fout = fopen([ICsubdir '/Units.txt'],'w');
fprintf(fout,'%s\n', '## Pls look at the snippet "CosmologyGetUnits.C" of enzo src,\n');
fprintf(fout,'%s\n', '## and also how sp_Etot_enzo is obtained in "Generate_IC.m" for clarity.\n');
fprintf(fout,'%s\n', '## density unit (g/cm^3); velocity unit (cm/s); specific energy unit (cm^2/s^2) -- for enzo');
fprintf(fout,'%e %e %e\n', DensityUnits, VelocityUnits, SpecificEnergyUnits);
fclose(fout);
