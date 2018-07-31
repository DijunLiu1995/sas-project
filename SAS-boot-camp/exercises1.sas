
%let wrds=wrds-cloud.wharton.upenn.edu 4016;
options comamid=TCP remote = WRDS;
signon user = _prompt_;

rsubmit;

data CH1_EX1_RD;
	set comp.funda (keep = gvkey fyear conm xrd revt sich indfmt datafmt popsrc consol);
	if fyear = 2006;
	if indfmt = 'INDL';
	if datafmt = 'STD';
	if popsrc = 'D';
	if consol = 'C';

	if xrd =. then xrd = 0;
	rd_sales_ratio = xrd / revt;
	if rd_sales_ratio <= 0.05 then delete;
	if rd_sales_ratio = . then delete;
	drop indfmt datafmt popsrc consol;

run;


proc download data = CH1_EX1_RD;
run;

endrsubmit;

proc freq data = CH1_EX1_RD;
	tables sich;
run;


proc univariate data = tax;
	var rd_sales_ratio;
run;


****** Exercise 2;


rsubmit;

data tax;
	set comp.fundq (keep = gvkey cusip txtq piq cshoq prccq fyearq datadate indfmt datafmt popsrc consol );
	if fyearq = 2006;
	if indfmt = 'INDL';
	if datafmt = 'STD';
	if popsrc = 'D';
	if consol = 'C';
	if piq >0;
	if piq = . then delete;
	if txtq = . then delete;
	if txtq <= 0 then delete;
	if cshoq = . then delete;
	if cshoq <= 0 then delete;
	if prccq =. then delete;
	taxrate = txtq / piq;

	mktvalue = cshoq * prccq;

	drop indfmt datafmt popsrc consol;

run;


proc sql;
	create table tax as select a.*, b.sich 
	from tax as a, comp.funda as b 
	where (a.gvkey = b.gvkey) and (a.fyearq = b.fyear);
quit;


proc download data = tax;
run;

endrsubmit;



proc freq data = tax;
	table sich;
run;

proc sort nodupkey data = tax;
	by gvkey fyearq cshoq;
run;

proc sort data = tax;
	by taxrate;
run;

proc rank data = tax
	out = tax_rank
	ties = low
	groups = 10;
	var taxrate;
	ranks etrrank;
run;

	
data lowestten;
	set tax_rank;
	if etrrank = 0;
run;

proc freq data = lowestten;
	table sich;
run;

proc univariate data = lowestten;
	var taxrate;
run;


************ Part 4;


rsubmit;
data compsample;
	set comp.anncomp
		(keep = gvkey cusip coname ticker exec_fullname year salary
			bonus age title);
	if year = 2005 or 2006;
	if salary ne .;
	if year ne .;
	if bonus ne .;
	cashcomp = salary + bonus;
run;

proc download data = compsample;
run;

endrsubmit;

proc sort data = compsample;
	by gvkey year;
run;


proc sql;
	create table mytable
	as select a.*, b.cashcomp as lag_cashcomp
	from compsample as a 
	left join compsample as b
	on (a.exec_fullname = b.exec_fullname)
	and (a.gvkey = b.gvkey) and (a.year = b.year + 1);
quit;

data mytable;
	set mytable;
	chgcash = cashcomp - lag_cashcomp;
	percentage_raise = chgcash / lag_cashcomp;

data compsample2;
	set mytable;
	if year = 2006;
	if chgcash =. then delete;
	if percentage_raise =. then delete;
run;

proc rank data = compsample2 out = cashcomp_rank ties = low groups = 10;
	var percentage_raise; ranks raiserank;
run;

data top_ten_perc;
	set cashcomp_rank;
	if raiserank = 9;
run;

proc univariate data = top_ten_perc;
	var percentage_raise;
run;
