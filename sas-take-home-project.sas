**************************************************************************************
*                                                                                    *
*						SAS Take Home Project - David Zynda                          *
*                                                                                    *
**************************************************************************************;
libname llv07 'C:\Users\dzynda\Documents\Fall-2018\sas-project';

%let wrds = wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=wrds;
signon username=_prompt_;
Libname rwork slibref=work server=wrds;


******** Step 1: Estimate a Firm Specific Beta ********;

*** Examine firms from Compustat with either one of the two fiscal year-ends: 12/31/2006 and 12/31/2006;

rsubmit;

data compFunda;
	set comp.funda (where = (indfmt = 'INDL' and datafmt = 'STD' and popsrc = 'D'
							and consol = 'C' and (fyear = 2000 or fyear = 2006) and fyr = 12)
							keep = gvkey cusip cik tic conm sich fyr fyear datadate exchg sale dlc dltt dd1
							prcc_f csho mkvalt at ib indfmt datafmt popsrc consol SICH ACT AT CHE DLC DP LCT PPENT PPEGT RECT RECTR);

run;

proc download data = compFunda;
run;

endrsubmit;

data llv07.compFunda;
	set compFunda;
run;





*** Match these firms with 250 daily returns from CSRP.DSF after the fiscal year end. ;



rsubmit;

data crspReturns;
	set crsp.dsf (where = (year(date) = 2001 or year(date)= 2007) 
	keep = date ret cusip);
run;

proc download data = crspReturns;
run;

endrsubmit;

data llv07.crspRet;
	set crspReturns;
	xcusip = cusip;
	drop cusip;
run;


* Join Crsp data to compustat. Match by cusip to each daily crsp ret;
* MAYBE REVISE AND USE LINK TABLE;
proc sql;
	create table 		combo1
	as select			a.*, b.*
	from llv07.crspret as a left join llv07.compfunda as b
	on substr(a.xcusip,1,6) = substr(b.cusip,1,6);
quit;

proc sort data = combo1;
	by fyear cusip date;
run;

* Make the set a little smaller. Remove empty obs. Keep only variables needed for CAPM;
data combo1_trimmed;
	set combo1;
	if xcusip ne ' ';
	if cusip ne ' ';
	if ret ne .;
	if fyear ne .;

	keep xcusip date ret fyear;
run;


*** Match each daily return with the value weighted market return from the crsp.dsi file;


rsubmit;

data crsp_dsi; set crsp.dsi;
	if year(date) = 2001 or year(date) = 2007;
run;

proc download data = crsp_dsi;
run;

endrsubmit;

data crsp_dsi;
	set crsp_dsi;
	dates = date;
	drop date;
run;

proc sql;
	create table 		dsi_crsp_comp
	as select			a.vwretd, a.dates, b.*
	from 				crsp_dsi as a left join combo1_trimmed as b
	on					a.dates = b.date;
quit;


*** Estimate Beta for these firms;

proc sort data = dsi_crsp_comp nodupkey;
	by xcusip fyear date;
run;

data llv07.dsi_crsp_comp;
	set dsi_crsp_comp;
	if xcusip ne ' ';
	if fyear;
	if date;
	if vwretd;
run;

proc reg data = llv07.dsi_crsp_comp plots=none outtest = beta;
	by xcusip fyear;
	model ret = vwretd;
run;

data llv07.beta;
	set beta;
	firm_beta = vwretd;
run;

	




































