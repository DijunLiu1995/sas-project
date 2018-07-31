/****************************************************************************************************************
	PROJECT: 		SAS Camp 2018 - Day 1 Chaney & Philipich Replication
	DATE:			7/18/2018

****************************************************************************************************************/


* Basic Initializations;
%let wrds=wrds-cloud.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;

libname savedata 'C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp';


*%include "C:\Users\nssei\Desktop\2018 SAS Camp\Day 1\macros.sas";



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

*bring down crsp_compustat merged linktable;
rsubmit;
data link;
	set crsp.ccmxpf_linktable;
	keep gvkey lpermno linkdt linkenddt usedflag linkprim linktype;
run;
proc download data=link;quit;
endrsubmit;

proc sql;
	create table comp_link as 
	select a.*, b.lpermno as permno
	from comp_sp as a left join link /*???? means some Compustat dataset*/
	(where=(linktype in ('LC', 'LU') and linkprim in ('P','C'))) as b
	on a.gvkey=b.gvkey and ((b.linkdt <=a.datadate) or (b.linkdt=.B)) and ((a.datadate <=b.linkenddt) or (b.linkenddt=.E));
quit;
*11650;
/* no duplicates */
proc sort data=comp_link nodupkey;
	by gvkey fyear;
quit;

/*****Event Study*****/

*input event date and get dataset into event study format***;
data event; set comp_link;
	edate='10jan2002'd; *the shredding announcement date;
	format edate date9.;
	if permno=. then delete;
	if cusip8="" then delete;
run;
*7206;
rsubmit;

*create macro variables;
%let ndays=240; *number of weekdays of estimation period (the authors are not explicit on this number);
%let offset = 40; *number of weekdays between end of estimation period and event date;
%let begdate=0; *relative weekday at beginning of abnormal returns cumulation period;
%let enddate=2; *relative weekday at end of abnormal cumulation period;

proc upload data=event;
quit;

*gather daily stock returns from the beginiing of the Beta estimation period through the end of the event date;
proc sql;
	create table event1 as
	select a.*, b.ret, b.date
	from event as a left join crsp.dsf as b
	on (a.permno=b.permno) and ((intnx('WEEKDAY', a.edate, -&offset -&ndays))<=b.date<=(intnx('WEEKDAY', a.edate, &enddate))); *INTNX (P.374 SAS Base Programming);
quit;

*Get in daily market returns;
data crsp_dsi; set crsp.dsi;
	if year(date) ge 2000 and year(date) le 2002;
run;

proc download data=event1;
quit;
*1854817;
proc download data=crsp_dsi; quit;
*752;

endrsubmit;
*add daily market returns; *vwretd= Total Return Value-Weighted Index;

proc sql;
	create table event1b as
	select a.*, b.vwretd
	from event1 as a left join crsp_dsi as b
	on (a.date=b.date);
quit;
*1854817;

*create macro variables (outside rsubmit);
%let ndays=240; *number of weekdays of estimation period (the authors are not explicit on this number);
%let offset = 40; *number of weekdays between end of estimation period and event date;
%let begdate=0; *relative weekday at beginning of abnormal returns cumulation period;
%let enddate=2; *relative weekday at end of abnormal cumulation period;

*set tmp return to only have a value during thte estimation period and not during the cooling off or event period;
data event1c; set event1b;
	if date<intnx('WEEKDAY', edate, -&offset) then tmp_ret=ret; else tmp_ret=.;
run;

proc sort data=event1c;
	by permno edate date;
quit;

*calculate expected returns. p=outputs this expectation.;
proc reg data=event1c noprint;
	by permno edate;
	model tmp_ret=vwretd;
	*this is basically CAPM beta;
	output out=event2 p=expected_ret;
quit;


data event2b; set event2;
	if expected_ret=. then delete;
run;


*Calculate abnormal returns;
proc sql;
	create table 	event3
	as select		permno, edate, exp(sum(log(1+ret))) - 
						exp(sum(log(1+expected_ret))) as ab_ret, n(ret) as nobs
	from 			event2b (where = (date between intnx('WEEKDAY', edate, &enddate) 
						and intnx('WEEKDAY', edate, &enddate)))
	group by		permno, edate
	order by		permno, edate;

quit;

*Add the CAR's to the main data set;

proc sql;
	create table	CAR
	as select		a.*, b.ab_ret
	from			event as a left join event3 as b
	on 				a.permno = b.permno;
quit;

data savedata.CAR;
	set CAR;
run;
