**********************************************************
*
*  IBES practice
*
**********************************************************;

%let wrds=wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon user = _prompt_;


* File -> Import data ;


proc print data = sample;
run;

rsubmit;
proc upload data = sample;


proc sql;
	create table forecast
	as select A.ticker, A.cusip, B.oftic, A.statpers, 
			  A.fpedats, A.meanest, A.actual, A.anndats_act	
	from ibes.statsum_epsus as A, sample as B
	where (A.oftic = B.oftic) and (year(B.year)=year(A.fpedats)) and A.fpi='1';

proc download data = forecast; 
run;

endrsubmit;

proc print data = forecast;
	var oftic statpers fpedats meanest actual anndats_act;
	format anndats_act YYMMDDn8. ;
	run;
quit;




* ex 2;


data sample;
	input oftic $ 1-6 year $8-15;
	eyear=input(year,yymmdd8.);
	cards;
MSFT   20051231
	;
run;
rsubmit;
proc upload data = sample;

proc sql; 

	create table forecast as select
	A.ticker, A.cusip, B.oftic, A.actdats, A.estimator, A.analys,
	A.value, A.actual, A.anndats_act
	from ibes.det_epsus as A, sample as B
	where (a.oftic=B.oftic) and (year(B.eyear) = year(A.fpedats)) and A.fpi='1';

proc download data = forecast; run;

endrsubmit;

proc sort data = forecast;
	by analys actdats;
run;

data forecast;
	set forecast;
	by analys actdats;
	if last.analys;
run;

proc print data = forecast;

	var oftic estimator analys actdats value actual anndats_act;
	format anndats_act YYMMDDn8. actdats YYMMDDn8.;
run;



* use proc sql to get the last analyst forecast;



rsubmit;
proc upload data = sample;

proc sql; 

	create table forecast as select
	A.ticker, A.cusip, B.oftic, A.actdats, A.estimator, A.analys,
	A.value, A.actual, A.anndats_act
	from ibes.det_epsus as A, sample as B
	where (a.oftic=B.oftic) and (year(B.eyear) = year(A.fpedats)) and A.fpi='1';

	create table	forecast2
	as select		*
	from 			forecast
	group by		analys
	having actdats = max(actdats)
	;
quit;

proc download data = forecast2; run;

endrsubmit;
















