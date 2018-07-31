LIBNAME day3 "C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp";
*%include "C:\Users\nssei\Desktop\2018 SAS Camp\Day 1\macros.sas";
%LET wrds = wrds-cloud.wharton.upenn.edu 4016;
OPTIONS COMAMID = TCP remote=WRDS;
SIGNON user='bdzynda2' password = 'J0hnP@ul2';

/*
rsubmit;
data annualfile;
	set comp.funda;
	keep gvkey fyear at sale sich;
	if 2004 <= fyear <= 2006;
	if indfmt = 'INDL';
	if datafmt = 'STD';
	if popsrc = 'D';
	if consol = 'C';
run;
endrsubmit;
*/


rsubmit;
proc sql;
	create table annualfile
	as select gvkey, fyear, at, sale, sich
	from comp.funda
	where (fyear >=2004 and fyear <= 2006)
	and indfmt = 'INDL' 
	and datafmt = 'STD'
	and popsrc = 'D'
    and consol = 'C'

;quit ;

proc download data = annualfile;
run;

endrsubmit;




proc sql;
	create table lag_table
	as select a.*, b. at as lag_at,
				   b. sale as lag_sale
	from annualfile as a left join
		 annualfile as b
	on a.gvkey = b.gvkey and a.fyear = b.fyear + 1
	order by gvkey, fyear;
quit;



