* Exercises Day Two;


libname crsp_ex 'C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp';

%let wrds = wrds-cloud.wharton.upenn.edu 4016;
options comamid = tcp remote = WRDS;
signon user='bdzynda2' password = 'J0hnP@ul2';

rsubmit;

data monthlycrsp;
	set crsp.msf (keep = cusip prc vol date ret);
	if year(date) > 2003 and year(date) < 2007;
	if cusip = '58933Y10' or cusip = '47816010' or cusip = '71708110';
run;

proc download data = monthlycrsp;
endrsubmit;
signoff;

proc sort data = monthlycrsp;
	by = date cusip;
run;

proc print data = monthlycrsp; run;



* Ex 3;


%let wrds = wrds-cloud.wharton.upenn.edu 4016;
options comamid = tcp remote = WRDS;
signon user='bdzynda2' password = 'J0hnP@ul2';

rsubmit;

data cashdiv;
	set crsp.dseall (keep = cusip COMNAM  DIVAMT date );
	if year(date) > 2003 and year(date) < 2007;
	if cusip = '58933Y10' or cusip = '47816010' or cusip = '71708110';
	if divamt ne .;
	year = year(date);
run;

proc download data = cashdiv;
endrsubmit;
signoff;

proc sort data = cashdiv;
	by = date cusip;
run;

proc print data = cashdiv; run;


* use proc means to sum the individual groups


* Ex 4;

%let wrds = wrds-cloud.wharton.upenn.edu 4016;
options comamid = tcp remote = WRDS;
signon user='bdzynda2' password = 'J0hnP@ul2';

rsubmit;

data comprets;
	set crsp.dsf (keep = cusip  ret date );
	if year(date) = 2006;
	if cusip = '58933Y10' or cusip = '47816010' or cusip = '71708110';
	year = year(date);
run;

proc download data = comprets;
endrsubmit;
signoff;

proc sort data = comprets;
	by date;
run;

proc print data = comprets;
run;


proc sql;
	create table comprets2 
	as select distinct cusip, exp(sum(log(1+ret)))-1 as comp_ret,
						n(ret) as n_obs
	from comprets
	group by cusip;
quit;

proc print data = comprets2;
run;

	

