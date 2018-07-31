libname crsp_ex 'C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp';

%let wrds = wrds-cloud.wharton.upenn.edu 4016;
options comamid = tcp remote = WRDS;
signon user= _prompt_;

rsubmit;

proc contents data = crsp.dsf; 
run;

endrsubmit;


rsubmit; 

*60 days before and 2 after;
%let day_before=61;
%let day_after=2;

data events;
format date0 date1 date2 date9.;
input cusip $8. date0 yymmdd10.;
date1 = date0 - &day_before;
date2 = date0 + &day_after;
* specify specific cusip and event date manually via cards;
CARDS;
45920010 19980102
59491810 20010405
24702R10 20041121
;
run;

proc print data=events(obs=2); run;
proc sort  data=events; by cusip date1; run;

proc sql;
	create table esfx
	as select a.*, b.*
	from events as a
	left join crsp.dsf  (keep= date cusip prc vol ret) as b
	on a.cusip = b.cusip and (a.date1 <= b.date <= a.date2);
quit;

proc download data=esfx;
endrsubmit;
signoff;

proc sort data = esfx out = crsp_ex.esfx; 
	by cusip date; 
run;

proc print data = crsp_ex.esfx;

proc means data = esfx n;
	var date;
	by cusip;
run;




* Example 2;

%let wrds = wrds-cloud.wharton.upenn.edu 4016;
options comamid = tcp remote = WRDS;
signon user= _prompt_;


rsubmit;

data sample;
	format date1 date2 date9.;
	input cusip $8. date1  date2;

	CARDS;
	45920010 7305 17531
	59491810 7305 17531
	24702R10 7305 17531
	;
proc print data = sample; 
run;


proc sort data = sample;
	by cusip date1; 
run;

proc sql;
	create table stkdiv
	as select a.*, b.*
	from sample as a 
	left join crsp.dsedist(keep = cusip distcd facshr dclrdt paydt) as b
	on a.cusip = b.cusip and (a.date1 <= b.dclrdt <= a.date2)
	where distcd > 4999 and distcd < 6000; *in the 5000's indicates a code of dividend payout for this variable on crsp;
quit;


proc download data = stkdiv;
endrsubmit;
signoff;

proc sort data = stkdiv out = crsp_ex.stkdiv; 
	by cusip dclrdt;
run;

proc print data = crsp_ex.stkdiv; run;
