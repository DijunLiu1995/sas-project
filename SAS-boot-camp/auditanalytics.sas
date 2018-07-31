/* Audit Analytics */

LIBNAME day3 "C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp";
*%include "C:\Users\nssei\Desktop\2018 SAS Camp\Day 1\macros.sas";
%LET wrds = wrds-cloud.wharton.upenn.edu 4016;
OPTIONS COMAMID = TCP remote=WRDS;
SIGNON user='bdzynda2' password = 'J0hnP@ul2';

rsubmit;

data auditopin; set audit.auditopin;
	keep company_fkey  fiscal_year_of_op fiscal_year_end_op auditor_fkey
	     auditor_name best_edgar_ticker audit_op_key auditor_city auditor_state;
		 where best_edgar_ticker = "AAPL";
run;


proc download data = auditopin;
run;

endrsubmit;


data day3.auditopin; set auditopin; run; quit;


ods html file = 'C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp\AAPL_audopin.xls';
proc print data = auditopin; run;
ods html close;



* Audit Fees;



rsubmit;
data sample1; set audit.auditfees
	(keep = company_fkey fiscal_year fiscal_year_ended audit_fees non_audit_fees best_edgar_ticker);
	if best_edgar_ticker in ('AIG', 'GE', 'GM');
run;

proc download data = sample1;
run;

endrsubmit;


data day3.sample1; set sample1; run; quit;


proc report data = sample1 windows;
	columns company_fkey best_edgar_ticker fiscal_year audit_fees non_audit_fees;
	define company_fkey / display;
	define fiscal_year / display;
	define audit_fees / display;
	define non_audit_fees / display;
	define best_edgar_ticker / display;
quit;




rsubmit;
data sample2; set audit.auditchange
	(keep = company_fkey 
			dismiss_date 
			auditor_resigned 
			dismiss_name 
			Engaged_auditor_name 
			dismissed_GC
			dismissed_disagree 
			best_edgar_ticker);
	if dismissed_disagree > 0 and best_edgar_ticker > " ";
run;

proc download data=sample2;
run;


endrsubmit;


proc sort data=sample2;
	by best_edgar_ticker dismiss_date;
quit;


proc report data = sample1 (obs=30) windows;
	column company_fkey best_edgar_ticker dismiss_date
			dismiss_name engaged_auditor_name;
		define company_fkey / display;
		define dismiss_date / display;
		define dismiss_name / display;
		define engaged_auditor_name / display format = $15.;
		define engaged_auditor_name / display format = $15.;
		define best_edgar_ticker / display;
	run;


rsubmit;

data sample1; 
	set audit.auditsox302(keep = company_fkey
							best_edgar_ticker
							sig_deficiency
							material_weakness
							is_effective
							noteff_acc_rule
							noteff_acc_reas_phr
							period_end_date_num);
	if is_effective = 0 and year(period_end_date_num) = 2004 and best_edgar_ticker > " ";

proc download data = sample1;
run;

endrsubmit;




/********************************************************************
*
*  Exercises
*
********************************************************************/

*Question 1;

rsubmit;

proc sql;

	create table auditfees
	as select company_fkey,
			  fiscal_year_ended,
              audit_fees
	from audit.auditfees
	where year(fiscal_year_ended) = 2008

	;
quit;


proc download data = auditfees;
run;

proc sql;

	create table auditopin
	as select company_fkey,
			  fiscal_year_end_op,
			  auditor_fkey,
			  auditor_name,
			  audit_op_key,
			  auditor_city,
			  auditor_state
	from audit.auditopin
	where year(fiscal_year_end_op) = 2008

	;
quit;


proc download data = auditopin;
run;

endrsubmit;


proc sql;
	
	create table answer1a
	as select a.*, b.*
	from auditopin as a left join
		 auditfees as b
	on a.company_fkey = b.company_fkey and a.fiscal_year_end_op = b.fiscal_year_ended
	;
quit;



proc sql;

	create table answer1b
	as select auditor_city, auditor_name, SUM(audit_fees) as city_audit_fees
	from answer1a
	group by auditor_name, auditor_city
	order by city_audit_fees DESC
	;
quit;





*Question 2;

rsubmit;

proc sql;

	create table fee_change
	as select company_fkey, fiscal_year_ended, audit_fees, best_edgar_ticker
	from audit.auditfees
	where year(fiscal_year_ended) GE 2000 and year(fiscal_year_ended) LE 2006
	
	;
quit;

proc download data = fee_change; run;

endrsubmit;



proc sql;

	create table fee_diff
	as select a.company_fkey, a.best_edgar_ticker,
			  b.audit_fees as Fees_2006 Label='Fees 2006',
			  a.audit_fees as Fees_2000 Label='Fees 2000',
			  (b.audit_fees - a.audit_fees) as fee_increase,
			  Calculated fee_increase / fees_2000 as Percent_incr
	from fee_change as a, fee_change as b
	where a.company_fkey = b.company_fkey AND year(a.fiscal_year_ended) = 2000 
										  AND year(b.fiscal_year_ended) = 2006

	order by fee_increase DESC

	;
quit;
	


* Exercise 3;


rsubmit;

proc sql;

	create table fired_auditor
	as select company_fkey,
			  dismiss_date, 
			  auditor_resigned, 
			  dismiss_name, 
			  subsidiary_name,
			  best_edgar_ticker
	from audit.auditchange
	where year(dismiss_date) GE 2000 and year(dismiss_date) LE 2006
	      AND auditor_resigned NE 1

	;
quit;

proc download data = fired_auditor;
run;

endrsubmit;



proc sql;

	create table firing_by_death_squad
	as select dismiss_name, count(dismiss_name) as firings
	from fired_auditor
	where subsidiary_name IS MISSING
	Group by dismiss_name
	order by firings desc

	;
quit;



































