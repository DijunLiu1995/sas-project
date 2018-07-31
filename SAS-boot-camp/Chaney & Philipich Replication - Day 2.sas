/****************************************************************************************************************
	PROJECT: 		SAS Camp 2018 - Day 1 & 2 Chaney & Philipich Replication
	DATE:			7/23/2018

****************************************************************************************************************/


* Basic Initializations;
%let wrds=wrds-cloud.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;

libname home 'C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp';

%include "C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp\MacroRepository.sas";



* Data Collection of Compustat variables;
rsubmit;
data comp; set comp.funda ( where= (indfmt='INDL' 
									and datafmt='STD' 
									and popsrc='D' 
									and consol='C')
							keep = gvkey cusip cik tic conm sich 
								   fyr fyear datadate sale dlc ib
								   dltt dd1 prcc_f csho mkvalt at  
								   indfmt datafmt popsrc consol);
	if year(datadate) ge 1999;
	if year(datadate) le 2001;
	if gvkey ne .;
	if at gt 0;
run;

proc download data=comp;
quit;
endrsubmit;
* 33599; 

* Create variables to allow Compustat to be merged 
with Audit Analytics and also control variables;
data comp; set comp;
	*Calendar year now matches audit analytic's definition;
	if fyr le 5 then calendar_year = fyear+1; 
	else calendar_year = fyear;
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





*bring down crsp_compustat linktable*;
rsubmit;
data link; set crsp.ccmxpf_linktable;
	keep gvkey lpermno linkdt linkenddt usedflag linkprim linktype;
run;

proc download data = link;
quit;
endrsubmit;

*merge link table with compustat data*;
proc sql;
	create table 	comp_link
	as select		a.*, b.lpermno as permno
	from			comp_sp as a left join link 
					(where=(LINKTYPE in ('LC', 'LU') 
					 and linkprim in ('P','C'))) as b
	on 				a.gvkey = b.gvkey and ((b.linkdt <= a.datadate) 
					or (b.linkdt = .B)) and ((a.datadate <= b.linkenddt) 
					or (b.linkenddt = .E));
quit; 
*11650; 


*Make sure there are no duplicates;
proc sort data = comp_link nodupkey;
	by gvkey fyear;
quit;
*10992; 



****EVENT STUDY****;

*input event date and get data set into event study format***;
data event; set comp_link;
	edate = '10jan2002'd;	*the shredding announcement date*;
	format edate date9.;
	if permno = . then delete;
	if cusip8 = "" then delete;
run;
*7206; 

*upload data set to words*;
rsubmit;

*Create macro variables;
%let ndays = 240;   *number of weekdays of estimation period 
 					 (the authors are not explicit on this number);
%let offset = 40;   *number of weekdays between end of estimation 
					 period and event date;
%let begdate = 0;   *Relative weekday at beginning of abnormal 
					 return cumulation period;
%let enddate = 2;   *Relative weekday at end of abnormal return 
					 cumulation period; 

proc upload data=event;
quit;

*Gather daily stock returns from the beginning  of the Beta estimation 
 period through the end of the event date*;
proc sql;
	create table	event1
	as select		a.*, b.ret, b.date
	from			event as a left join crsp.dsf as b
	on				(a.permno = b.permno)
					and ((intnx('WEEKDAY', a.edate, -&offset -&ndays))
						<= b.date <= (intnx('WEEKDAY', a.edate, &enddate)));
quit;

*get in daily market returns;
data crsp_dsi; set crsp.dsi;
	if year(date) ge 2000 and year(date) le 2002;
run;

proc download data=event1;
quit;
*1854817;

proc download data=crsp_dsi;
quit;
*752; 

endrsubmit;


*add daily market returns;
*vwretd = Total Return Value-Weighted Index; 
proc sql;
	create table 	event1b
	as select		a.*, b.vwretd
	from 			event1 as a 
	left join 		crsp_dsi as b
	on				(a.date = b.date);
quit;
*1854817; 

*Macro variables;
%let ndays = 240;   *number of weekdays of estimation period (the authors are not explicit on this number);
%let offset = 40;   *number of weekdays between end of estimation period and event date;
%let begdate = 0;   *Relative weekday at beginning of abnormal return cumulation period;
%let enddate = 2;   *Relative weekday at end of abnormal return cumulation period; 


*Set tmp return to only have a value during the estimation 
 period and not during the cooling off;
data event1c; set event1b;
	if date < intnx('WEEKDAY', edate, -&offset) 
    then tmp_ret = ret; else tmp_ret = .;
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
*1854817  to 1839266;

*Calculate abnormal returns;
proc sql;
	create table	event3 
	as select 		permno, edate, exp(sum(log(1+ret))) - 
					exp(sum(log(1+expected_ret))) as ab_ret, 
					n(ret) as nobs
	from			event2b (where = (date between 
					intnx('WEEKDAY', edate, &begdate)
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
*7206; 


* Saving the dataset to the library I specified; 
data home.CAR; set CAR; 
run;



****END OF DAY 2!****;




*********Obtain Data for variables on Audit Analytics**********;
*find out which auditors and audit offices issue the opinion for each client*;


rsubmit;

data audit; 
	set audit.auditopin;
	if fiscal_year_of_op >= 1999;
	keep company_fkey audit_op_key auditor_fkey auditor_name going concern auditor_city
		 auditor_state auditor_state_name auditor_region auditor_con_sup_reg sig_date_of_op_s
		 fiscal_year_of_op fiscal_year_end_op best_edgar_ticker matchfy_balsh_assets matchqu_incmst_rev_ttm;
run;

proc download data = audit;
run;




data auditfees; 
	set audit.auditfeesr;
	keep company_fkey fiscal_year_ended audit_fees non_audit_fees total_fees benefits_fees
		 it_fees tax_fees audit_related_fees other_fees restatement currency_code_fkey;
	run;

proc download data = auditfees;
run;
endrsubmit;


data audit; set audit;
	NMO = ((year(fiscal_year_end_op) - 1960) * 12) + month(fiscal_year_end_op);
run;


data auditfees; set auditfees;
	NMO = ((year(fiscal_year_ended) - 1960) * 12) + month(fiscal_year_ended);
run;



*keep only restated fees and drops the incorrect unrestated fees;

proc sort data = auditfees; 
	by company_fkey fiscal_year_ended descending restatement descending audit_fees;
proc sort data = auditfees out=auditfees2 nodupkey;
	by company_fkey fiscal_year_ended; 
run;
quit;


proc sql;

	create table auditanalytics as 
	select distinct a.*, b.*
	from audit as a left join auditfees2 as b
	on (a.company_fkey = b.company_fkey) and (a.NMO - 1 <= b.nmo <= a.nmo +1)

	;
quit;



*** Merge audit analytics with compustat/crsp data generates 7,215;

proc sql undo_policy = none;
	
	create table 	CIK as
	select distinct	a.*, b.*
	from CAR as a left join auditanalytics as b
	on (a.cik = b.company_fkey) and (a.nmo - 1 <= b.nmo <= a.nmo + 1)

	;
quit;


* Merge audit analytics with compustat data using ticker. should be 2252;

proc sql undo_policy = none;
	
	create table 	ticker as
	select distinct	a.*, b.*
	from CAR as a left join auditanalytics as b
	on (a.ticker = b.best_edgar_ticker) and (a.nmo - 1 <= b.nmo <= a.nmo + 1)
	where (a.ticker ne " ") and (b.best_edgar_ticker ne " ")

	;
quit;
	

*remove duplicates from both and merge together. ;

proc sort data = cik out = cik1 nodupkey;
	by gvkey nmo;
run;

proc sort data = ticker out = ticker1 nodupkey;
	by gvkey nmo;
run;

data comp_audit; 
	merge cik1 ticker1;
	by gvkey nmo;
run;



data comp_audit; 
	set comp_audit;
	auditfees_scaled = (audit_fees / 1000000) / AT;
	nonauditfees_scaled = (non_audit_fees / 1000000) / AT;
run;

*calculate variables of interest, fees mus be scaled by $1m ssince compustat is in a mil;

data comp_audit; 
	set comp_audit;
	if auditor_city = "Houston" then Houston = 1; else Houston = 0;
run;

data comp_audit; set comp_audit;
	gics = substr(spgim,1,6);
run;

Data comp_audit ;
	set Comp_audit;
	if gics =202010 then commercial_gics = 1; else commercial_gics = 0;
	if gics = 101020 then oilgas_gics = 1; else oilgas_gics = 0;
	if gics = 551010 then utility_gics = 1; else utility_gics = 0;
	if gics = 201060 then machinery_gics = 1; else machinery_gics = 0;
run;

%ff48(data = comp_audit, newvarname = industryff48, sic = sich, out=comp_audit); run;




data comp_audit; set comp_audit;
	if industryff48 = 30 then commercial_ff48 = 1; else commercial_ff48 = 0;
	if industryff48 = 31 then utility_ff48 = 1; else utility_ff48 = 0;
	if industryff48 = 21 then machinery_ff48 = 1; else machinery_ff48 = 0;
run;


data Anderson;
	set comp_audit;
	if gvkey = 006127 then delete;
	if (490 <= NMO <= 501);
	if auditor_fkey ne 5 then delete;
	if company_fkey ne .; if audit_fees ne .;
run;

Data Anderson; set Anderson;
	if (spmim = "10") then SP500_comp = 1; else sp500_comp = 0;
	if (spmim = "10") or (spmim = "91") or (spmim = "92") then sp1500_comp = 1; else sp1500_comp = 0;
run;


%WT(data=anderson, out=winsorize, byvar=fyear, vars=salesgrowth auditfees_scaled nonauditfees_scaled leverage ab_ret,
	type = W, pctl = 1 99, drop = N);run;



proc sort data = winsorize; by sp1500_comp;
run;

data winsorize1; set winsorize;
	if mve = . then delete;
run;




proc means data = winsorize1 n mean p25 p50 p75;
	var at mve ib roa;
	where SP1500_comp = 1;
run;


proc means data = Winsorize1 n mean p25 p50 p75;
	var audit_fees non_audit_fees total_fees;
	where SP1500_comp = 1;
run;


proc means data = winsorize n mean std min p5 p10 p25 p50 p75 p90 p95 max;

	var ab_ret		Houston		SalesGrowth		Audit_Fees
		Non_Audit_Fees Leverage	SP500_comp		Commercial_GICS
		Utility_GICS			Machinery_GICS;
		where SP1500_comp = 1;
run;

Data Winsorize; set Winsorize;
	if salesgrowth > 1 then SalesGrowth = 1;
run;

proc univariate data = winsorize1;
	var ab_ret;
	where sp1500_comp = 1;
	title 'C&P Replication: CAR Tests - All Office Returns';
run;


* Regressions ;

proc reg data = Winsorize1;
	model ab_ret = Houston salesgrowth auditfees_scaled nonauditfees_scaled leverage sp500_comp commercial_gics oilgas_gics
			utility_gics machinery_gics;
	where SP1500_comp = 1;
run;


proc reg data = Winsorize1;
	model ab_ret = Houston Salesgrowth auditfees_scaled nonauditfees_scaled leverage SP500_comp
					commerical_ff48 oilgas_ff48 utilityff48 machineryff48;
	where sp1500comp = 1;
run;































