**********************************************************
*
*  IBES Exercises
*
**********************************************************;

* Problem 1;


%let wrds=wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon user = _prompt_;

rsubmit;

data ibis2; 
	set ibes.statsum_epsus;
	if year(fpedats) = 2005;
	if fpi = '1'; /* current year, annual period */
	surprise = abs(actual - meanest);
	age = anndats_act - statpers;
	if surprise = . then delete;
run; 

proc download data = ibis2;
run;

endrsubmit;


































