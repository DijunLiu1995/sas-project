* Remember to change your LIBNAME and file directory to your personal settings;
libname DGM 'C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp';

options errors=3 noovp; options nocenter ps=max ls=120; options mprint source nodate symbolgen macrogen; 
options msglevel=i;

* Remember to change your MACROS file directory to your personal settings;
%include "C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp\macroRepository.sas";

ods html close; 
ods preferences;
ods html newfile=proc; 

%let wrds = wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=wrds;
signon username=_prompt_;
Libname rwork slibref=work server=wrds;

*Pull down IBES variables and calculate*;
rsubmit;
data ibes; set ibes.statsumu_epsus;
	if year(fpedats) ge 1986 and year(fpedats) le 1999;
	if fpi = '1';
	if cusip = '' then delete;
	keep cusip ticker oftic cname statpers fiscalp fpi numest meanest fpedats;
run;

proc download data=ibes;
run;
endrsubmit;

*pull down actual reported eps values from unadjusted file*;
rsubmit;
data ibes1; set ibes.actu_epsus;
	if pdicity = 'ANN';
	if cusip = '' then delete;
	if value=. then delete; 
	if year(pends) ge 1986 and year(pends) le 1999;
	keep cusip ticker oftic cname pdicity pends value anndats;
run;

proc download data=ibes1;
run;
endrsubmit;

data DGM.ibes_dgm; set ibes; run; quit; 
data DGM.ibes1_dgm; set ibes1; run; quit; 

/*alternate way of retrieving data;
rsubmit;
proc sql;
create table test as select distinct
a.cusip, a.ticker, a.oftic, a.fpedats, b.value
from ibes.statsumu_epsus as a, ibes.actu_epsus as b
where a.oftic=b.oftic and a.fpedats=b.pends and a.fpi='1' and b.periodicty='ANN'
and year(a.fpedats)>=1986 and year(a.fpedats)<=1999 and a.cusip ne '' and b.cusip ne ''; run; quit; 

proc download data=test; run; quit;
endrsubmit; */

*merge actual values with consensus analyst forecasts. 
Reduces count to 672,922 [7/31/15]*;
proc sql;
	create table	ibes2 as
	select			a.*, b.value, b.anndats
	from			DGM.ibes_dgm as a, DGM.ibes1_dgm as b
	where			a.cusip = b.cusip and a.fpedats = b.pends and a.cusip ne '';
quit;


*deleting forecasts after announcement reduces count to 671,270 [7/31/15];
data ibes2b; set ibes2;
	miss_forecast = meanest - value;			*calculate miss_forecast variable*;
	miss_forecast = round(miss_forecast,.01);	*round miss forecast to the nearest cent*;
	difference = statpers - anndats;			*create variable to see how long from time analysts issued forecasts and earnings were announced*;
	if difference > 0 then delete; 				*remove forecasts that happened after earnings were announced*;
run;

*Only keep the last forecast given before the earnings announcement date.
Reduces count to 64,484 [7/31/15]*;
proc sql;
	create table ibes3 as select distinct *
	from ibes2b
	group by oftic, fpedats
	having statpers = max(statpers);
quit;


*Bring down compustat quarterly data to calculate variables*;
rsubmit;
data compq; 
	set comp.fundq;
	if indfmt='INDL';	
	if datafmt='STD';		
	if popsrc='D';					
	if consol='C';	
	if gvkey = . then delete;
	if cusip = '' then delete;
	if fyearq ge 1985 and fyearq le 1999;
	keep gvkey datadate fyearq fqtr cusip tic conm txtq piq;
run;

proc download data=compq;
run;
endrsubmit;

data DGM.compq_gm; set compq; run; quit; 

***Remove all qtr 4 observations from dataset;
*reduces observations from 611,683 to 463,182 [7/31/15]; 
data q3; 
	set DGM.compq_gm;
	if fqtr = 4 then delete;
run; quit;

***sum up taxes and income over the first three quarters to develop an ETR for Q1-3;
proc sql;
	create table EtrQ3 as select 
	a.*, sum(a.txtq) as txtQ3, sum(a.piq) as piQ3, sum(a.fqtr) as accQ3
	from q3 as a
	group by gvkey, fyearq
	order by gvkey, fyearq;
quit;

***delete quarters 1 and 2 as well as observations that do not have data for all three quarters, create ETRQ3.
Reduces sample to 152,467 [7/31/15];
data EtrQ3a; 
	set EtrQ3;
	if fqtr = 1 then delete;
	if fqtr = 2 then delete;
	if accQ3 ne 6 then delete;
	EtrQ3 = txtQ3 / piQ3;
run; quit;

***Calculate ETR for Q4****;
proc sql;
	create table EtrQ4 as select 			
	a.*, sum(a.txtq) as txtQ4, sum(a.piq) as piQ4, sum(a.fqtr) as accQ4
	from DGM.compq_gm as a
	group by gvkey, fyearq
	order by gvkey, fyearq;
quit;

*retaining Q4 reduces sample to 148,383 [7/31/15];
data EtrQ4a; 
	set EtrQ4;
	if fqtr = 1 then delete;
	if fqtr = 2 then delete;
	if fqtr = 3 then delete;
	if accQ4 ne 10 then delete;
	EtrQ4 = txtQ4 / piQ4;
run; quit;

*merge q3 ETR into Q4 Etr. Result is 148,383 observations [7/31/15];
proc sql;
	create table Etr as select
	a.*, b.EtrQ3, b.piQ3
	from EtrQ4a as a, EtrQ3a as b
	where (a.gvkey = b.gvkey) and (a.fyearq = b.fyearq);
quit;

*Create dependent variable Etr4_Etr3 which meaures the difference between 
the final year end ETR and the ETR after the first three quarters. Reduces count to 129,764 [7/31/15];
data Etr2; 
	set Etr;
	Etr4_Etr3 = EtrQ4 - EtrQ3;
	if Etr4_Etr3 = . then delete;
run; quit;

*Bring down compustat annual data to calculate variables.
Retrieves 161,703 observations [7/31/15]*;
rsubmit;
data comp; 
	set comp.funda;
	if indfmt='INDL';		
	if datafmt='STD';		
	if popsrc='D';					
	if consol='C';	
	if gvkey = . then delete;
	if cusip = '' then delete;
	if fyr le 5 then year = (fyear+1);
	if fyr ge 6 then year = fyear;
	if year ge 1985 and year le 1999;
	keep gvkey datadate fyear fyr year tick cusip conm PI CSHPRI AT TXDI TXDFED TXDS TXDFO TXP TXR ACT CHE LCT DLC DP;
run;

proc download data=comp;
run;
endrsubmit;

data DGM.comp_dgm; set comp; run; quit; 

*reduces count to 140,473 [7/31/15];
data comp1; 
	set DGM.comp_dgm;
	tax_owed = (TXP - TXR) / PI;  /*DGM use tax return data but use this in sensitivity analyses as a measure that can be constructed from WRDS*/
	accruals = (IB - OANCF) / PI;
	STR = .35;
	if year = 1986 then STR = .46;
	if year = 1987 then STR = .40;
	if year ge 1988 and year le 1992 then STR = .34;
	lag_gvkey = lag(gvkey);
	lag_fyear = lag(fyear);
	lag_ACT = lag(act);
	lag_CHE = lag(CHE);
	lag_LCT = lag(lct);
	lag_DLC = lag(DLC);
	lag_TXP = lag(TXP);
	if lag_gvkey ne gvkey then delete;
	if (lag_fyear + 1) ne fyear then delete;
	CH_CA = ACT - lag_ACT;
	CH_Cash = CHE - lag_che;
	CH_CL = LCT - lag_LCT;
	CH_STD = DLC - lag_DLC;
	CH_TP = TXP - lag_TXP;
	if TXDI = . then TXDI = TXDFED + TXDS + TXDFO; *not sure if I should do this or not;
	if accruals = . then accruals = (CH_CA - CH_Cash - CH_CL + CH_STD + CH_TP - DP) / PI;
	Deferred_tax = TXDI / PI;
	CUSIP8=SUBSTR(CUSIP,1,8); 					*Create 8 digit CUSIP;
run; quit;

*alternative way to retrieve code;
rsubmit;
proc sql;
create table sql_way as select distinct
a.gvkey, a.datadate, a.fyear, a.fyr, a.tick, a.cusip, a.conm, a.PI, a.CSHPRI, a.AT, a.TXDI, a.TXDFED, a.TXDS, a.TXDFO, a.TXP, a.TXR, a.ACT, a.CHE, a.LCT, a.DLC, a.DP,
b.act as lag_act, b.che as lag_che, b.lct as lag_lct, b.dlc as lag_dlc, b.txp as lag_txp
from comp.funda as a, comp.funda as b
where a.gvkey=b.gvkey and a.fyear=b.fyear+1 and a.gvkey ne . and a.cusip ne '' and
and a.indfmt='INDL' and a.datafmt='STD' and a.popsrc='D' and a.consol='C'  
and b.indfmt='INDL' and b.datafmt='STD' and b.popsrc='D' and b.consol='C'; run; quit; 

proc download data=sql_way;
endrsubmit; 

*Merge quarterly data of compustat in with annual compustat data.
Generates 117,469 observations [7/31/15]*;
proc sql;
	create table merge as select			
	a.*, b.EtrQ3, b.Etr4_Etr3, b.EtrQ4, b.piQ4, b.piQ3
	from comp1 as a, etr2 as b
	where (a.gvkey = b.gvkey) and (a.datadate = b.datadate);
quit;



*************************************************************
* 			Above completed by Mark on Day 4 				*
*			Spencer will complete the rest on Day 5 	



*merge ibes data with compustat ;

data ibes4;
	set ibes3;
	format fpedats yymmdd8.;
run;



proc sql;
	create table ibes_comp
	as select a.*, b.*
	from merge as a , ibes3 as b
	where  (substr(a.cusip,1,8) = substr(b.cusip,1,8)) and (a.datadate = b.fpedats) ;

quit;


data ibes_comp1;
	set ibes_comp;
	miss_amount = meanest - (pi * (1 - etrq3)) / cshpri;
	if  meanest * (1-etrq3) < 0 then miss = 1; else miss = 0;
	induced_chg_ETR = (((str - etrQ3)*(value - meanest) * CSHPRI / (1 - STR)) / pi);
run;

/*
data ibes_comp_tr;
	set ibes_comp1;
	if miss_forecast > -0.05; 
	if miss_forecast < 0.05;
	if miss_forecast ne .;
	if etrq4 > 0;
	if etrq3 > 0;
	if piq3 > 0;
	if piq4 > 0;
	if at ne .;
	if at >= 50;
	if tax_owed ne .;
	if miss_amount ne . ;
	if induced_chg_ETR ne .;
	if miss ne .;
	if accruals ne . ;
	if deferred_tax ne . ;
	if etr4_etr3 ne .;
	if pi ne .;

run; */

data ibes_comp_tr;
	set ibes_comp1;
	if miss_forecast > 0.05 then delete;
	if miss_forecast < -.05 then delete;
	if etrq4 < 0 then delete;
	if etrq3 < 0 then delete;
	if piq4 < 0 then delete;
	if piq3 < 0 then delete;
	if etrq3 = . then delete;
	if miss_forecast = . then delete;
	if etr4_etr3 = . then delete;
	if miss_amount = . then delete;
	if miss = . then delete;
	if induced_chg_etr = . then delete;
	if tax_owed = . then delete;
	if accruals = . then delete;
	if deferred_tax = . then delete;
	if pi = . then delete;
	if at =. then delete;
	if at le 50 then delete;
run;


%WT(data = ibes_comp_tr, out = finalDat, byvar = none, vars = ETR4_etr3 etrq3 induced_chg_etr, type = T, pctl = 1 99, drop = Y)

data finalDat;
	set finalDat;
	miss_miss_amount = miss*miss_amount;
	miss_accruals = miss * accruals;
	miss_deferred_tax = miss*deferred_tax;
run;

proc means data = finalDat n mean std p25 median p75;
	var etr4_etr3 miss_forecast miss_amount miss induced_chg_etr tax_owed etrQ3 etrQ4 accruals deferred_tax pi at;
run;

proc corr data = finalDat;
	var etr4_etr3 miss miss_amount  induced_chg_etr tax_owed etrQ3 accruals;
run;

proc ttest data = finalDat;
	var etr4_etr3 miss_amount;
run;

proc surveyreg data = finalDat;
	cluster gvkey;
	class year;
	model etr4_etr3 = miss miss_amount miss_miss_amount induced_chg_etr tax_owed etrq3 year / solution ;
run;

proc reg data = finalDat;
	model etr4_etr3 = miss miss_amount miss_miss_amount induced_chg_etr tax_owed etrq3 accruals miss_accruals deferred_tax miss_deferred_tax;
run;
