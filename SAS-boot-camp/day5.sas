%let wrds = wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=wrds;
signon username=_prompt_;
Libname rwork slibref=work server=wrds;

rsubmit;

proc contents data = risk.rmdirectors; 
run;

data sample1;
	set risk.rmdirectors (keep = cusip ticker year fullname director_detail_id age female dirsince 
												num_of_shares comp_membership audit_membership cg_membership);
	if ticker = 'DELL' and year = 2008;
	dir_tenure = year - dirsince;
run;


proc download data = sample1; run;
endrsubmit;

proc sort data = sample1; 
	by descending num_of_shares;
run;

proc report data = sample1;
	column fullname age female dir_tenure num_of_shares comp_membership audit_membership cg_membership;
	define fullname / display format = $25.;
	define age / display format = 8.;
	define female / display format = $8.;
run;



rsubmit;

proc contents data = risk.rmgovernance varnum; run;

data sample1;
	set risk.rmgovernance (keep = ticker coname year cboard labylw lachtr supermajor_pcnt ppill gparachute);
	if year < 2010 and year > 2006;
	if cboard = 'YES' then E1 = 1; else E1 = 0;
	if labylw = "YES" then E2 = 1; else E2 = 0;
	if lachtr = "YES" then E3 = 1; else E3 = 0;
	if supermajor_pcnt > 50 then E4 = 1; else E4 = 0;
	if ppill = "YES" then E5 =1; else E5 = 0;
	if gparachute = "YES" then E6 = 1; else E6 = 0;
	E_score = sum(of E1-E6);
run;



proc download data = sample1;
run;

endrsubmit;

proc freq data = sample1; 
	tables year*E_score / nocol nopercent; run;

proc univariate data = sample1;
	var E_score;
run;





* creating link table;

rsubmit;

data compustat1;
	set comp.funda
			(keep = gvkey fyear tic cusip datadate indfmt datafmt popsrc consol);
	if indfmt = 'INDL';
	if datafmt = 'STD';
	if popsrc = 'D';
	if consol = 'C';
	if tic = 'AAPL';
	if fyear ge 2000 and fyear lt 2003;
run;

proc sql;
	create table sample1 as 
	select a.*, b.lpermno as permno
	from compustat1 as a left join crsp.ccmxpf_linktable
		(where = (usedflag=1 and linkprim in ('P','C'))) as b
		on a.gvkey and b.gvkey
	and ((b.linkdt <= a.datadate) or (b.linkdt = .B))
	and ((a.datadate <= b.linkenddt) or (b.linkenddt = .E));
run;


proc sql;
	create table sample2 as 
	select a.*, b.ret
	from sample1 as a left join crsp.dsf as b
	on a.permno = b.permno
	and a.datadate = b.date;
run;

proc download data = sample2;
run;

endrsubmit;

proc print data = sample2;
	var tic gvkey permno datadate fyear ret;
run;



rsubmit;

data crsp1;
	set crsp.dsenames (where = (ticker = 'AAPL'));
	keep ticker cusip gvkey;
run; quit;

data compustat1;
	set comp.funda (where = (tic = 'AAPL'));
	keep tic cusip gvkey;
run; quit;

proc download data = crsp1;
run;

proc download data = compustat1;
run;

endrsubmit;

proc sort data = compustat1 nodupkey; by tic cusip gvkey; run;

proc print data = crsp1;
run;












