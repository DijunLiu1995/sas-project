
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

%include "C:\Users\dzynda\Documents\Fall-2018\sas-project\MacroRepository.sas";

******** Step 1: Estimate a Firm Specific Beta ********;

*** Examine firms from Compustat with either one of the two fiscal year-ends: 12/31/2006 and 12/31/2006;


title1 'SAS Take Home Project';

title2 'Gather Data';
rsubmit;

data compFunda;
	set comp.funda (where = (indfmt = 'INDL' and datafmt = 'STD' and popsrc = 'D'
							and consol = 'C' and (fyear = 2000 or fyear = 2006) and fyr = 12)
							keep = gvkey cusip cik tic conm sich fyr fyear datadate exchg sale dlc dltt dd1
							prcc_f csho mkvalt ib indfmt datafmt popsrc consol SICH ACT AT CHE DLC DP LCT PPENT PPEGT RECT RECTR );


							
run;

proc download data = compFunda;
run;

endrsubmit;

proc sort data = compFunda nodupkey;
 by gvkey fyear datadate;
run;

data llv07.compFunda;
	set compFunda;
run;


proc datasets library = work;
	delete compFunda;
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

proc sort crspReturns nodupkey;
	by cusip date;
run;

data llv07.crspRet;
	set crspReturns;
	xcusip = cusip;
	drop cusip;
run;

proc datasets library = work;
	delete crspReturns;
run;


* Join Crsp data to compustat. Match by cusip to each daily crsp ret and on the same year;

proc sql;
	create table 		combo1
	as select			a.*, b.*
	from llv07.crspret as a left join llv07.compfunda as b
	on substr(a.xcusip,1,6) = substr(b.cusip,1,6) and year(a.date) = b.fyear + 1;
quit;

proc sort data = combo1 nodupkey;
	by fyear xcusip date;
run;

* Make the set a little smaller. Remove empty obs. Keep only variables needed for CAPM;
data combo1_trimmed;
	set combo1;
	if xcusip ne ' ';
	if cusip ne ' ';
	if ret ne .;
	if fyear ne .;
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


* Only keep firms with trading days approximately a year long. ;
data dsi_crsp_comp;
	set dsi_crsp_comp;
	if _N_ > 240;
run;

*** Estimate Beta for these firms;

proc sort data = dsi_crsp_comp nodupkey;
	by gvkey fyear date;
run;

data llv07.dsi_crsp_comp;
	set dsi_crsp_comp;
	if gvkey ne ' ';
	if fyear;
	if date;
	if vwretd;
run;

proc means data = llv07.dsi_crsp_comp;
	by gvkey fyear;
	var ret vwretd;
run;


title2 'Regression for firm specific beta';
proc reg data = llv07.dsi_crsp_comp plots=none outtest = beta ;
	by gvkey fyear;
	model ret = vwretd;
run;

data llv07.beta;
	set beta;
	firm_beta = vwretd;
run;




















/******************************************************************************************************
*
*          Step 2: Discretionary Accruals	http://www.bhwang.com/txt/Discretionary-Accruals-Code.txt
*
******************************************************************************************************/
title2 'Estimate Discretionary Accruals for year 2001 (fyear 2000)';


* That garbage was done in another script with code provided by Spencer. ;


proc means data = llv07.dis_acc00 mean ;
	by gvkey;
	var DCAModJones1991Int;
	output out = dis_ass1 mean=DiscreationaryAccruals;
run;


* Get mean dis thing for last four year for fyeaer 2000 and 2006. ;
proc means data = llv07.dis_acc06 mean ;
	by gvkey;
	var DCAModJones1991Int;
	output out = dis_ass2 mean=DiscreationaryAccruals;
run;


*Add fyear to merge them together as distinct yearly obs;
data dis_ass1;
	set dis_ass1;
	fyear = 2000;
	drop _freq_ _type_;
run;

data dis_ass2;
	set dis_ass2;
	fyear = 2006;
	drop _freq_ _type_;
run;

*Concatenate the two datasets;
data disAccs;
	set dis_ass1 dis_ass2;
run;

proc sort data = disAccs;
	by gvkey fyear;
run;

*Merge Discretionary Accruals with beta;
proc sql;
	create table 		beta2
	as select a.*, b.*
	from llv07.beta as a left join disAccs as b
	on a.gvkey = b.gvkey and a.fyear = b.fyear;
quit;

*Save it to library. Make sure use abs value;

data llv07.beta2;
	set beta2;
	DiscreationaryAccruals = abs(DiscreationaryAccruals);
run;


*****************************************************;
* Book tax differences;

* For 2000;
rsubmit;
data btd1;
	set comp.funda (where = (indfmt = 'INDL' and datafmt = 'STD' and popsrc = 'D'
							and consol = 'C' and (1996 le fyear and fyear le 2000) and fyr = 12)
							keep = gvkey cusip cik tic conm sich fyr fyear datadate exchg sale dlc dltt dd1
							prcc_f csho mkvalt ib indfmt datafmt popsrc consol SICH ACT AT CHE DLC DP LCT PPENT PPEGT RECT RECTR pi txc);
			
run;

proc download data = btd1;
run;

endrsubmit;


data btd1;
	set btd1;
	btd = (ib - txc/0.35) / at;
run;

proc means data = btd1;
	by gvkey;
	var btd;
	output out = btd00 mean=btd;
run;

data btd00;
	set btd00;
	fyear = 2000;
	keep gvkey fyear btd;
run;


* For 2006;
rsubmit;
data btd2;
	set comp.funda (where = (indfmt = 'INDL' and datafmt = 'STD' and popsrc = 'D'
							and consol = 'C' and (2002 le fyear and fyear le 2006) and fyr = 12)
							keep = gvkey cusip cik tic conm sich fyr fyear datadate exchg sale dlc dltt dd1
							prcc_f csho mkvalt ib indfmt datafmt popsrc consol SICH ACT AT CHE DLC DP LCT PPENT PPEGT RECT RECTR pi txc);
			
run;

proc download data = btd1;
run;

endrsubmit;


data btd2;
	set btd2;
	btd = (ib - txc/0.35) / at;
run;

proc means data = btd2;
	by gvkey;
	var btd;
	output out = btd06 mean=btd;
run;

data btd06;
	set btd06;
	fyear = 2006;
	keep gvkey fyear btd;
run;


data btd_final;
	set btd00 btd06;
run;

proc sort data = btd_final nodupkey;
	by gvkey fyear;
run;


*Merge btd with beta;
proc sql;
	create table 		llv07.beta3
	as select a.*, b.*
	from llv07.beta2 as a left join btd_final as b
	on a.gvkey = b.gvkey and a.fyear = b.fyear;
quit;

	



*****************************************************;
* Audit Quality;


* join by cik;

rsubmit;

data big_dudes;
	set audit.auditopin (where = ((year(fiscal_year_end_op) = 2000 or year(fiscal_year_end_op) = 2006) and (month(fiscal_year_end_op) = 12) and day(fiscal_year_end_op) = 31)
						keep = company_fkey fiscal_year_end_op auditor_name best_edgar_ticker);
run;



data tics;
	set comp.funda (where = (indfmt = 'INDL' and datafmt = 'STD' and popsrc = 'D'
							and consol = 'C' and (fyear = 2000 or fyear = 2006) and fyr = 12)
							keep = gvkey cusip cik tic conm sich fyr fyear datadate exchg sale dlc dltt dd1
							prcc_f csho mkvalt ib indfmt datafmt popsrc consol SICH ACT AT CHE DLC DP LCT PPENT PPEGT RECT RECTR pi uniami txc);
	drop exchg sale dlc dltt dd1 prcc_f csho mkvalt ib indfmt datafmt popsrc consol SICH ACT AT CHE DLC DP LCT PPENT PPEGT RECT RECTR pi uniami txc;
run;

proc sql;

	create table big_dudes2 
	as select a.*, b.*
	from tics as a left join big_dudes as b
	on a.cik = b.company_fkey ;
quit;



proc download data = big_dudes2;
run;

endrsubmit;


data big_dudes;
	set big_dudes2;
	if AUDITOR_NAME = 'PricewaterhouseCoopers LLP' 
	or AUDITOR_NAME = 'KPMG LLP' 
	or AUDITOR_NAME = 'Ernst & Young LLP' 
	or AUDITOR_NAME = 'Arthur Andersen LLP' 
	or AUDITOR_NAME = 'Deloitte & Touche LLP' then bign = 1;
	else bign = 0;

	keep gvkey fyear bign;
run;

proc sql;
	create table llv07.beta4
	as select a.*, b.*
	from llv07.beta3 as a left join big_dudes as b
	on a.gvkey = b.gvkey and a.fyear = b.fyear;
quit;


*****************************************************************************;
* Get Analyst and dispersion data;

rsubmit;

data ibs;
	set ibes.statsum_epsus (where = ((year(fpedats)=2000 or year(fpedats)=2006) and (month(fpedats)=12))
	keep =  cusip numest highest lowest fpedats);

	Dispersion = highest - lowest;
	fyear = year(fpedats);
	if numest = . then numest = 0;
	* I have no idea what deflate dispersion by ending stock price means;
run;

proc download data = ibs;
run;

endrsubmit;

* Add cusips to the betas;
proc sql;
	create table llv07.beta4
	as select a.*, b.cusip, b.gvkey
	from llv07.beta4 as a left join llv07.compfunda as b
	on a.gvkey = b.gvkey;
quit;

* merge ibes on cusip;

proc sql;
	create table llv07.beta5
	as select a.*, b.*
	from llv07.beta4 as a left join ibs as b
	on substr(a.cusip, 1, 6) = substr(b.cusip, 1, 6);
quit;



/******************************************************************************************************
*
*          Step 3: Control variables
*
******************************************************************************************************/



rsubmit;

data lalaland;
	set comp.funda; where  (indfmt = 'INDL' and datafmt = 'STD' and popsrc = 'D'
							and consol = 'C' and (fyear = 2000 or fyear = 2006) and fyr = 12);
							keep  fyear gvkey csho prcc_c BKVLPS dt at;
	
run;

proc download data = lalaland;
run;

endrsubmit;

* Make sure variables are correct;
data controls;
	set lalaland;
	size = log(csho*prcc_c);
	btm = bkvlps / prcc_c;
	lev = dt / at;
	prc = (prcc_c)**(-1);
run;

* During this merge, many duplicates are made;
proc sql;
	create table llv07.final_beta
	as select a.*, b.*
	from llv07.beta5 as a left join controls as b
	on a.gvkey = b.gvkey and a.fyear = b.fyear;
quit;

*Duplicates removed;
proc sort data = llv07.final_beta nodupkey;
	by gvkey fyear;
run;





/******************************************************************************************************
*
*          Step 4: Analysis
*
******************************************************************************************************/

title2 'Analysis and Results';

%WT(data = llv07.final_beta, out=final, byvar= fyear, vars = firm_beta DiscreationaryAccruals
																btd bign numest dispersion 
																size btm lev prc, 	type = T, pctl = 1 99);
run;

proc means data = final mean std min p25 median p75 max n;
	var firm_beta DiscreationaryAccruals btd bign numest dispersion size btm lev prc;
run;


proc corr data = final pearson spearman;
	var firm_beta DiscreationaryAccruals btd bign numest dispersion size btm lev prc;
run;


* Regression with disc. accruals;

proc reg data = final;
	model firm_beta = DiscreationaryAccruals size btm lev prc;
run;


* Regression with btd;

proc reg data = final;
	model firm_beta = btd size btm lev prc;
run;


* Regression with Big N accounting;

proc reg data = final;
	model firm_beta = bign size btm lev prc;
run;



* Regression with number of analysts ;

proc reg data = final;
	model firm_beta = numest size btm lev prc;
run;




* Regression with dispersion ;

proc reg data = final;
	model firm_beta = dispersion size btm lev prc;
run;



* Regression with all;

proc reg data = final;
	model firm_beta = DiscreationaryAccruals btd bign numest dispersion size btm lev prc;
run;


