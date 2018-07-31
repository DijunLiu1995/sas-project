%let wrds = wrds-cloud.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon user=_prompt_;

rsubmit;

proc downloard data = compann;

endrsubmit;

signoff;

data compann;
	set comp.funda(keep = gvkey cusip tic fyear fyr at sale ib indfmt datafmt popsrc consol sich);
	if indfmt = 'INDL';
	if datafmt = 'STD';
	if popsrc = 'D';
	if consol = 'C';
	if fyear GE 1995 and fyear LE 2005;
run;

proc download data = compann;
run;

proc sort data = compann;
	by gvkey fyear fyr;
run;


data sample1; set compann;
	lag_gvkey = lag(gvkey);
	lag_fyear = lag(fyear);
	lag_at = lag(at);
	if gvkey NE lag_gvkey then lag_at = .;
	avg_at = (at + lag_at) / 2;
	if avg_at > 0 then ROA = ib / avg_at;
	drop indfmt datafmt popsrc consol;
run;

proc print data = sample1(obs = 20);
run;

proc univariate data = sample1;
	var roa;
run;



* Example 2 ****************************************;

%let wrds=wrds-cloud.wharton.upenn.edu 4016;
options comamid = TCP remote = WRDS;
signon user = 'bdzynda2' password = 'J0hnP@ul2';






rsubmit;
data compqtr;
	set comp.fundq(keep=gvkey cusip tic fyearq datadate rdq dlttq
					indfmt popsrc consol datafmt);
	if fyearq = 2006;
	if indfmt = 'INDL';
	if datafmt = 'STD';
	if popsrc = 'D';
	if consol = 'C';
run;
data compsic;
	set comp.company (keep = gvkey sic);
	if sic GE 3000 and sic LE 4000;
run;

proc sql; 
	create table compmerged
	as select a.*, b.*
	from compqtr as a
	inner join compsic as b 
	on a.gvkey = b.gvkey;
quit;

proc download data = compmerged;
quit;
endrsubmit;

data example2; set compmerged;
	if missing (datadate) then delete;
	drop indfmt datafmt popsrc consol;
run;

proc print data = example2(obs=15);
run;
