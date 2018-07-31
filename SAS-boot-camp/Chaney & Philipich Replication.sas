*Basic Initializations;
%let wrds = wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=wrds;
signon username=_prompt_;
libname home 'C:\Users\Matthew\Desktop\SAS Camp\Data';
%include "C:\Users\Russ Hamilton\Documents\My SAS Files\9.4\SAS camp\macros.sas";

*Data Collection of Compustat variables*;
rsubmit;
data comp; set comp.funda ( where = (indfmt='INDL' and datafmt='STD' and popsrc='D' 
		and consol='C')
	keep = gvkey cusip cik tic conm sich fyr fyear datadate exchg sale dlc dltt dd1
		prcc_f csho mkvalt at ib indfmt datafmt popsrc consol);
	if year(datadate) ge 1999;
	if year(datadate) le 2001;
	if gvkey ne .;
	if at gt 0;
run;

proc download data=comp;
quit;
endrsubmit;

*Create variables to allow Compustat to be merged with Audit Analytics and also control variables;
data comp; set comp;
	*Calendar year now matches audit analytic's definition;
	if fyr le 5 then calendar_year = fyear+1; else calendar_year = fyear;
	*NMO to facilitate merging with Audit Analytics;
	nmo = ((year(datadate)-1960)*12)+fyr;
	*Trim CUSIP to match Audit Analytics length;
	cusip8 = substr(cusip,1,8);
	*Format Ticker;
	length Ticker $6.; Ticker = tic;
	*Create lagged variables;
	lag_at=lag(at);
	lag_sale=lag(sale);
	lag_gvkey=lag(gvkey);
	lag_fyear=lag(fyear);
	*check lag variables;
	if gvkey NE lag_gvkey or lag_fyear+1 ne fyear then lag_sale=.;
	if gvkey NE lag_gvkey or lag_fyear+1 ne fyear then lag_at=.;
	*Create key controls;
	salesgrowth=(sale-lag_sale)/lag_sale;
	ROA = ib / ((at+lag_at)/2);
	MVE = mkvalt;
	if mve=. then mve=PRCC_F*CSHO;
	*Create alternate definitions for leverage if one of the components of LT debt is missing*;
	if (DD1 ne .) and (dltt ne .) then leverage = (dd1 + dltt)/at;
	else if (dd1 = .) then leverage = dltt / at;
	else if (dltt = .) then leverage = dd1 / at;
	*Only keep certain NMOs (data for 10/31/2000 to 9/30/01);
	if (490 <= NMO <= 501);
	drop indfmt datafmt popsrc consol;
run;

*get historical S&P index code and GICS industry classification from Compustat*;
rsubmit;
data spindex; set comp.sec_mth;
	if year(datadate) ge 2000 and year(datadate) le 2001;
	keep spgim spmim gvkey datadate;
run;

proc download data=spindex;
run;
endrsubmit;

*merge in historical S&P index codes with compustat data*;
proc sql;
	create table 	comp_sp
	as select 		a.*, b.spgim, b.spmim
	from 			comp as a left join spindex as b
	on				(a.gvkey = b.gvkey) and (a.datadate = b.datadate);
quit;



****END OF DAY 1!****;



*bring down crsp_compustat merged database*;
rsubmit;
data link; set crsp.ccmxpf_linktable;
	keep gvkey lpermno linkdt linkenddt usedflag linkprim;
run;

proc download data = link;
quit;
endrsubmit;

*merge link table with compustat data*;
proc sql;
	create table 	comp_link
	as select		a.*, b.lpermno as permno
	from			comp_sp as a left join link (where=(usedflag=1 and linkprim in ('P','C'))) as b
	on				a.gvkey = b.gvkey and ((b.linkdt <= a.datadate) or (b.linkdt = .B)) and ((a.datadate <= b.linkenddt) or (b.linkenddt = .E));
quit;

*Make sure there are no duplicates;
proc sort data = comp_link nodupkey;
	by gvkey fyear;
quit;

****EVENT STUDY****;

*input event date and get data set into event study format***;
data event; set comp_link;
	edate = '10jan2002'd;	*the shredding announcement date*;
	format edate date9.;
	if permno = . then delete;
	if cusip8 = "" then delete;
run;

*upload data set to words*;
rsubmit;

*Macro variables;
%let ndays = 240;   *number of weekdays of estimation period (the authors are not explicit on this number);
%let offset = 40;   *number of weekdays between end of estimation period and event date;
%let begdate = 0;   *Relative weekday at beginning of abnormal return cumulation period;
%let enddate = 2;   *Relative weekday at end of abnormal return cumulation period; 

proc upload data=event;
quit;

*Gather daily stock returns from the beginning  of the Beta estimation period through the end of the event date*;
proc sql;
	create table	event1
	as select		a.*, b.ret, b.date
	from			event as a left join crsp.dsf as b
	on				(a.permno = b.permno)
					and ((intnx('WEEKDAY', a.edate, -&offset -&ndays))
						<= b.date <= (intnx('WEEKDAY', a.edate, &enddate)));
quit;

*Add in daily market returns;
data crsp_dsi; set crsp.dsi;
	if year(date) ge 2000 and year(date) le 2002;
run;

proc download data=event1;
quit;

proc download data=crsp_dsi;
quit;
endrsubmit;

proc sql;
*add daily market returns*;
	create table 	event1b
	as select		a.*, b.vwretd
	from 			event1 as a left join crsp_dsi as b
	on				(a.date = b.date);
quit;


*Macro variables;
%let ndays = 240;   *number of weekdays of estimation period (the authors are not explicit on this number);
%let offset = 40;   *number of weekdays between end of estimation period and event date;
%let begdate = 0;   *Relative weekday at beginning of abnormal return cumulation period;
%let enddate = 2;   *Relative weekday at end of abnormal return cumulation period; 

*Set tmp return to only have a value during the estimation period and not during the cooling off or event period;
data event1c; set event1b;
	if date < intnx('WEEKDAY', edate, -&offset) then tmp_ret = ret; else tmp_ret = .;
run;

proc sort data=event1c;
	by permno edate date;
quit;

*Calculate expected returns. p= outputs this expectation.;
proc reg data=event1c noprint;
	by permno edate;
	model tmp_ret = vwretd;
	*This is basically CAPM Beta.;
	output out = event2 p=expected_ret;
quit;

*Remove missing observations;
data event2b; set event2;
	if expected_ret=. then delete;
run;



*Calculate abnormal returns;
proc sql;
	create table	event3 
	as select 		permno, edate, exp(sum(log(1+ret))) - 
		exp(sum(log(1+expected_ret))) as ab_ret, n(ret) as nobs
	from			event2b (where = (date between intnx('WEEKDAY', edate, &begdate)
		and intnx('WEEKDAY', edate, &enddate)))
	group by 		permno, edate
	order by		permno, edate;
quit;

***Add the CAR's to the main dataset***;
proc sql;
	create table	CAR
	as select 		a.*, b.ab_ret
	from			event as a left join event3 as b
	on	 			a.permno = b.permno;
quit;

*data savaData.CAR; set CAR;
*run;


****END OF DAY 2!****;



*****Obtain Data for variables on Audit Analytics********;
*find out which auditors and audit offices issue the opinion for each client*;
rsubmit;
data audit; set audit.auditopin;
	if fiscal_year_of_op >= 1999;
	keep company_fkey audit_op_key auditor_fkey auditor_name going_concern auditor_city auditor_state auditor_state_name auditor_region auditor_con_sup_reg
	sig_date_of_op_s fiscal_year_of_op fiscal_year_end_op best_edgar_ticker matchfy_balsh_assets matchqu_incmst_rev_ttm; 
run;

proc download data=audit;
run;

data auditfees; set audit.auditfeesr;
	keep company_fkey fiscal_year_ended audit_fees non_audit_fees total_fees benefits_fees it_fees tax_fees audit_related_fees other_fees restatement currency_code_fkey;
run;

proc download data=auditfees;
run;
endrsubmit;

*data sas2014.audit; set audit;
*data sas2014.auditfees; set auditfees; run; quit; 

*create a month counter variable (NMO) in each dataset);
data audit; set audit;
	NMO = ((year(fiscal_year_end_op) - 1960)*12) + month(fiscal_year_end_op);
run;

data auditfees; set auditfees;
	NMO = ((year(fiscal_year_ended) - 1960)*12) + month(fiscal_year_ended);
run;

*keep only restated fees and drops the incorrect unrestated fees*;
proc sort data = auditfees; by company_fkey fiscal_year_ended descending restatement descending audit_fees;
proc sort data= auditfees out=auditfees2 nodupkey; by company_fkey fiscal_year_ended; run; quit; 


*link the audit fees data to the audit opinions dataset to have information for audit variables;
proc sql;
	create table	auditanalytics as
	select distinct	a.*, b.*
	from			audit as a left join auditfees2 as b
	on				(a.company_fkey = b.company_fkey) and (a.NMO - 1 <= b.NMO <= a.NMO + 1);
quit;

***Merge audit analytics with compustat/Crsp data. Generates 7,215 observations [8/20/14]***;
proc sql undo_policy = none;
	create table	CIK as
	select distinct	a.*, b.*
	from			CAR as a left join auditanalytics as b
	on				(a.cik = b.company_fkey) and (a.nmo - 1 <= b.nmo <= a.nmo + 1);
quit;

***Merge audit analytics with compustat/Crsp using Ticker. Reduces count to 2,252 [8/20/14]***;
proc sql undo_policy = none;	
	create table	Ticker as
	select distinct	a.*, b.*
	from			CAR as a left join auditanalytics as b
	on				a.ticker = b.best_edgar_ticker and (a.nmo - 1 <= b.NMO <= a.nmo + 1)
	where			(a.ticker ne " ") and (b.best_edgar_ticker ne " ");
quit;

*remove duplicates from both and merge together. Deleting duplicates reduces count to 7,211 for cik and 2,249 for ticker*;
proc sort data=cik out=cik1 nodupkey;
	by gvkey nmo;
run;
proc sort data=ticker out=ticker1 nodupkey;
	by gvkey nmo;
run;
data comp_audit;
	merge cik1 ticker1;
	by gvkey nmo;
run;

*Calculate variables of interest, fees must be scaled by $1M since compustat is in Millions*;
data comp_audit; set comp_audit;
	auditfees_scaled = (audit_fees / 1000000) / AT;
	nonauditfees_scaled = (non_audit_fees / 1000000) / AT;
run;

*identify firms that were audited by the Houston office*;
data comp_audit; set comp_audit;
	if auditor_city = "Houston" then Houston = 1; else Houston = 0;
run;

*Create Dummies for the industries that Chaney & Philipich use in their XS regression. 

	The paper uses Global Industry Classification Standard (GICS) to identify industries (see Table 1). 
	We only have GICS for members of the S&P 1500.  GICS classifications contain 8 digits: 
	The 1st 6 digits identify the industry, and the last 2 digits identify the sub-industry.  
	For simplicity in coding, just keep the 1st 6 digits.;

Data Comp_audit; set Comp_audit;
	GICS	=	SUBSTR(spgim,1,6);
run;

*Create dummy variables for each of the industries that Chaney & Philipich use;
Data Comp_audit; set Comp_audit;
	If GICS = 202010		then Commercial_GICS	=1; 	else Commercial_GICS	=0;
	If GICS = 101020		then OilGas_GICS		=1; 	else OilGas_GICS		=0;
	If GICS = 551010 		then Utility_GICS		=1; 	else Utility_GICS		=0;
	If GICS = 201060		then Machinery_GICS 	=1; 	else Machinery_GICS		=0;
run;

%ff48(data = comp_Audit, newvarname=industryff48, sic = sich, out=comp_audit);run;

data comp_audit; set comp_audit;
	if industryff48 = 34 then commercial_ff48 = 1; else commercial_ff48 = 0;
	if industryff48 = 30 then oilgas_ff48 = 1; else oilgas_ff48 = 0;
	if industryff48 = 31 then utility_ff48 = 1; else utility_ff48 = 0;
	if industryff48 = 21 then machinery_ff48 = 1; else machinery_ff48 = 0;
run;
 

***Apply data restrictions. This reduces set to 946 observations [8/20/14]***;
data Anderson; set comp_audit;
	if gvkey = 006127 then delete;				*delete Enron*;
	if (490 <= NMO <= 501);						*keep only data for 10/31/2000 to 9/30/01*;
	if auditor_fkey ne 5 then delete;			*keep only Anderson client's*;
	if company_fkey ne . ; if audit_fees ne .;	*delete firms that are missing audit analytics data*;
run;

***identify firms in the S&P 500 and the S&P 1500***;
Data Anderson; set Anderson;
	*use compustat's historical defition of S&P membership*;
	if (spmim = "10") then SP500_Comp = 1; else sp500_comp = 0;
	if (spmim = "10") or (spmim = "91")	or (spmim = "92") then sp1500_comp = 1; else sp1500_comp = 0;
run;


*Winsorize the data using a macro*;
*winsorize the data to trim the highest and lowest 1 percent*;
%include "C:\Users\Russ Hamilton\Documents\My SAS Files\9.4\SAS camp\macros.sas";

*For each continuous variable, the extreme 1% of observations on either side is deleted;
	%WT(data=anderson, out=winsorize, byvar=fyear, vars=salesgrowth auditfees_scaled nonauditfees_scaled leverage ab_ret
	,type = W, pctl = 1 99, drop= N);run;

proc sort data = winsorize; by sp1500_comp; 
run;

*drop firms missing MVE. Reduces dataset to 945 [8/20/14]*;
data winsorize1; set winsorize;
	if mve = . then delete;
run;

proc means data = winsorize1 n mean p25 p50 p75;
	var	at mve ib roa;
	where SP1500_comp = 1;
run;

proc sort data = winsorize1; by SP500_comp;
run;

proc means data = Winsorize1 n mean p25 p50 p75 ;
	Var AUDIT_FEES	NON_AUDIT_FEES	TOTAL_FEES;
	By SP500_Comp;
	Where SP1500_Comp = 1;
run;

proc means data = Winsorize1 n mean p25 p50 p75 ;
	Var AUDIT_FEES	NON_AUDIT_FEES	TOTAL_FEES;
	Where SP1500_Comp = 1;
run;

*Obtain Descriptive Stats for variables in regressions.  Look for screwy observations;
proc means data = Winsorize n mean std min p5 p10 p25 p50 p75 p90 p95 max;
	Var ab_ret		Houston				SalesGrowth		AuditFees		NonAuditFees	Leverage	SP500_comp	
					Commercial_GICS		OilGas_GICS		Utility_GICS	Machinery_GICS;
	Where SP1500_Comp = 1;
run;

*Since some firms still show excessive sales growth, cap sales growth and ab_ret at 100%;
Data Winsorize; set Winsorize;
	if SalesGrowth > 1 then SalesGrowth = 1;
run; 

proc univariate data = Winsorize1;
	var ab_ret; 
	where sp1500_comp = 1;
	title 'C&P Replication: CAR Tests - All Office Returns';
run;

proc univariate data = Winsorize1;
	var ab_ret; 
	where Auditor_city = "Houston" and sp1500_comp = 1;
	title 'C&P Replication: CAR Tests - Houston Office Returns';
run;

proc sort data=winsorize1; by Houston;
run;

proc ttest data=winsorize1;
	class houston;
	var ab_ret;
	where sp1500_comp = 1;
	title 'C&P Replication: CAR Tests - Houston Office vs Other Office Returns';
run;

*Run cross-sectional regression test (table 9);
proc reg data = Winsorize1;
	model ab_ret = 	Houston				SalesGrowth		AuditFees_scaled		NonAuditFees_scaled	Leverage	SP500_Comp	
					Commercial_GICS		OilGas_GICS		Utility_GICS	Machinery_GICS;
	Where SP1500_Comp =1;
run;

*Re-run the same test using the "Fama French 48" definition for industries;
*Notice how the variable "Houston" no longer loads, but instead "OilGas" starts loading.  
This begins to give us a hint of the problems that Nelson, Price, & Rountree (2008 JAE) show in this study.
(Movements in Oil & Gas prices appear to drive the returns, and Andersen's Houston office had a lot of Oil & Gas 
clients.);	 
proc reg data = Winsorize1;
	model ab_ret = 	Houston				SalesGrowth		AuditFees_scaled		NonAuditFees_scaled	Leverage	SP500_Comp	
					Commercial_FF48		OilGas_FF48		Utility_FF48	Machinery_FF48;
	Where SP1500_Comp =1;
run;
