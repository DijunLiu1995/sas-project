ods html close;
ods preferences;
ods html newfile = proc;

%let wrds = wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=wrds;
signon username=_prompt_;
Libname rwork slibref=work server=wrds;

* Pull dow IBES variables and calculate;

rsubmit;
data ibes; 
	set ibes.statsumu_epsus;
	if year(fpedats) ge 1986 and year (fpedats) le 1999;
	if fpi = '1';
	if cusip = ' ' then delete;
	keep cusip ticker oftic cname statpers fiscalp fpi numest meanest
fpedats;
run;


proc download data = ibes;
run;
endrsubmit;


* pull down actual reported eps values from unadjusted file ;

rsubmit;
data ibes1; set ibes.actu_epsus;
	if pdicity = 'ANN';
 	if  cusip = ' ' then delete;
	if value = . then delete;
	if year(pends) ge 1986 and year(pends) le 1999 ;
	keep cusip ticker oftic cname pdicity pends value anndats;
run;

proc download data = ibes1;
run;

endrsubmit;

proc sql;
	create table 		ibes2 as 
	select 					a.*, b.value, b.anndats
	from 					ibes as a, ibes1 as b
	where 					a.cusip = b.cusip and a.fpedats = b.pends and a.cusip ne ' ';
quit;

data ibes2b; 
	set ibes2;
		miss_forecast = meanest - value;
		miss_forecast = round(miss_forecast, 0.01);
		if difference > 0 then delete;
run;

proc sql;
	create table			ibes3
	as select distinct *
	from ibes2b
	group by oftic, fpedats
	having statpers = max(statpers);
quit;


rsubmit;
data compq;
	set comp.fundq;
	if indfmt = 'INDL';
	if datafmt = 'STD';
	if popsrc = 'D';
	if consol = 'C';
	if gvkey = . then delete;
	if cusip = ' ' then delete;
	if fyearq ge 1985 and fyearq le 1999;
	keep gvkey datadate fyearq fqtr cusip tic conm txtq piq;
run;

proc download data = compq;
run;

endrsubmit;


data compq_gm; set compq;
run;

data q3;
	set compq_gm;
	if fqtr = 4 then delete;
run;
quit;


proc sql;

	create table EtrQ3 as select
	a.*, sum(a.txtq) as txtQ3, sum(a.piq) as piQ3, sum(fqtr) as accQ3
	from q3 as a
	group by gvkey, fyearq
	order by gvkey, fyearq;
quit;


data EtrQ3a;
set etrq3;
	if fqtr = 1 then delete;
	if fqtr = 2 then delete;
	if accQ3 ne 6 then delete;
	EtrQ3 = txtQ3 / piQ3;
run; quit;


proc sql;

	create table EtrQ4 as select
	a.*, sum(a.txtq) as txtQ4, sum(a.piq) as piQ4, sum(fqtr) as accQ4
	from compq_gm as a
	group by gvkey, fyearq
	order by gvkey, fyearq;
quit;

data EtrQ4a;
	set EtrQ4;
	if fqtr = 1 then delete;
	if fqtr = 2 then delete;
	if fqtr = 3 then delete;
	if accQ4 ne 10 then delete;
	etq4 = txtQ4 / piQ4;
run;
quit;

proc sql;
	create table Etr as select
	a.*, b.EtrQ3, b.piQ3
	from EtrQ4a as a, EtrQ3a as b
	where (a.gvkey = b.gvkey) and (a.fyearq = b.fyearq);
quit;



data etr2;
	set etr;
	etr4_etr3 = etrq4 - etrq3;
	if etr4_etr3 = . then delete;
run; quit;


rsubmit;
data comp;
	set comp.funda;
	if indfmt = 'INDL';
	if datafmt = 'STD';
	if popsrc = 'D';
	if consol = 'C';
	if gvkey = . then delete;
	if cusip = ' ' then delete;
	if fyr le 5 then year = (fyear + 1);
	if gyr ge 6 then year = fyear;
	if year ge 1985 and year le 1999;
	keep gvkey datadate fyear fyr year tick cusip conm PI CSHPRI at txdi txdfed txds txdfo txp txr act che lct dlc dp;
	run;

proc download data = comp;
run;
endrsubmit;

data comp1;
	set comp;
	tax_owed = (TXP - TXR) / PI;
	accruals = (IB - OANCF) / PI;
	str = 0.35;
	if year = 1986 then str = .46;
	if year = 1987 the str = .40;
	if year  = 1988 and year le 1992 then str = .34;
	lag_gvkey = lag(gvkey);
	lag_fyear= lag(fyear);
	lag_ACT = lag(act);
	lag_CHE = lag(che);
	lag_lct = lag(lct);
	lag_dlc = lag(dlc);
	lag_txp = lag(txp);
	if lag_gvkey ne gvkey then delete;
	if (lag_fyear + 1) ne fyear then delete;
	ch_ca = act - lag_act;
	ch_cash = che - lag_che;
	ch_cl = lct - lag_lct;
	ch_std = dlc - lag_dlc;
	ch_tp = txp - lag_txp;
	if txdi = . then txdi = txdfed + txds + txdfo;
	if accruals = . then accruals = (ch_ca - ch_cas - CH_cas - ch_cl + ch_std + ch_tp - dp / pi);
	deferred_tax = txdi / pi;
	cusip8  = substr(cusip, 1, 8);
run; quit;

proc sql;
	create table merge as select
	a.* , b.EtrQ3, b.Etr4_etr3, b.etrQ4, b.piQ4, b.piQ3
	from comp1 as a, etr2 as b
	where (a.gvkey = b.gvkey) and (a.datadate = b.datadate);
quit;

