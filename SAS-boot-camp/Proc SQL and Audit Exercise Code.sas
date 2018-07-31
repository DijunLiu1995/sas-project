
%LET wrds = wrds-cloud.wharton.upenn.edu 4016;
OPTIONS comamid = TCP remote=wrds;
SIGNON username = _prompt_;
LIBNAME c_drive 'C:\Users\user\Desktop\SAS CAMP DAY3';


*Basic format;
RSUBMIT;
PROC SQL;	
	CREATE TABLE 
	AS SELECT 
	FROM  AS 
	WHERE 
	ORDER BY ;
QUIT;
ENDRSUBMIT;



**************************************************************
PROC SQL Exercises
*************************************************************


*****STEP 1*****************************************************

*download 2004-2006 data, using DATA step;
RSUBMIT;
DATA proc_exercise;
	SET comp.funda;
	KEEP gvkey fyear at sale sich;
	IF (fyear >= 2004 and fyear <=2006);
		if indfmt='INDL';		
		if datafmt='STD';		
		if popsrc='D';					
		if consol='C';	
RUN;
PROC DOWNLOAD DATA = proc_exercise; RUN;
ENDRSUBMIT;
*generates 32,628 observations;


*download 2004-2006 data, using PROC SQL;
RSUBMIT;
PROC SQL;
	CREATE TABLE proc_exercise_alt
	AS SELECT gvkey, fyear, at, sale, sich
	FROM comp.funda 
	WHERE (fyear >= 2004 and fyear <=2006) AND
		indfmt='INDL' AND		
		datafmt='STD' AND		
		popsrc='D' AND					
		consol='C' 
	;
QUIT;
PROC DOWNLOAD DATA = proc_exercise_alt; RUN;
ENDRSUBMIT;
*generates 32,628 observations;



*******STEP 2 ********************************************;

*note: if we were doing lag variables with data steps,
 we would need to 
	1. proc sort
	2. data step to create each lag
	3. use if statement to confirm that company hasn't changed
	4. use if statement to confirm that year hasn't skipped
*but PROC SQL handles this in a single step!



*create lag variables; 
PROC SQL;
	CREATE TABLE lag_table

	AS SELECT a.*, b.at as lag_at label ="lag at", 
			b.sale as lag_sale label = "lag sales"

	FROM proc_exercise_alt as a LEFT JOIN
			proc_exercise_alt as b

	ON a.gvkey=b.gvkey AND a.fyear = (b.fyear +1)

	ORDER BY gvkey, fyear
	;
QUIT;
*generates 32,805 rows;



*******STEP 3 ********************************************;

PROC SQL;
	CREATE TABLE lag_table1

	AS SELECT *, (at - lag_at)/lag_at AS percent_change_at, 
		(sale-lag_sale)/lag_sale AS percent_change_sale,

		INT(sich/100) AS SIC2 

	FROM lag_table
	;
QUIT; 

*******STEP 4 ********************************************;
PROC SQL;
	CREATE TABLE lag_table2
	AS SELECT sic2, avg(percent_change_at) AS pct_increase,
		max(percent_change_sale) as max_sales_increase
	FROM lag_table1
	GROUP BY sic2
	;
QUIT;

*******STEP 5 ********************************************;

PROC SQL;
	CREATE TABLE lag_table3
	AS SELECT sic2, fyear, avg(percent_change_at) AS pct_increase,
		max(percent_change_sale) as max_sales_increase
	FROM lag_table1
	GROUP BY sic2, fyear
	
	;
QUIT;

******* END PROC SQL EXERCISES  *************************************;




*Audit Opinion example*;


rsubmit; 
data auditopin; set audit.auditopin; 
	keep company_fkey name fiscal_year_of_op fiscal_year_end_op auditor_fkey 
	auditor_name best_edgar_ticker audit_op_key auditor_city auditor_state; 
	where best_edgar_ticker = "AAPL"; 
run; 

proc download data=auditopin; 
run; 
endrsubmit; 


data c_drive.auditopin; set auditopin; run; quit; 

*book's way to write to Excel;
ods html file = 'C:\Users\user\Desktop\AAPL_audopin.xls'; 
proc print data=auditopin;run; 
ods html close;



**********************************************************
*Beter way to write to excel!;
********************************************************;

*create a new library for the excel sheet--saves lots of typing later;
LIBNAME my_XL 'C:\Users\user\Desktop\audit_opin.xls';

*erases existing data on the spreadsheet tab;
PROC SQL;
	drop table my_XL.sheet_name;
QUIT;

*writes new data to the worksheet tab;
DATA my_XL.sheet_name;
	SET auditopin;
RUN;

*releases the newly created Excel file so we can open it normally;
LIBNAME my_XL CLEAR;






*Audit Fee example*;



rsubmit;
data sample1; set audit.auditfees 
	(keep= company_fkey fiscal_year fiscal_year_ended audit_fees non_audit_fees best_edgar_ticker);
	if best_edgar_ticker in ("AIG","GE","GM");
run;

proc download data=sample1; 
run;
endrsubmit; 
 

data c_drive.sample1; set sample1; run; quit; 

proc report data=sample1 windows; 
	column company_fkey best_edgar_ticker fiscal_year audit_fees non_audit_fees; 
	define company_fkey / display; 
	define fiscal_year / display; 
	define audit_fees / display format=10.; 
	define non_audit_fees /display format=10.; 
	define best_edgar_ticker /display;
quit;





*Auditor Changes example*;

rsubmit; 
data sample2; set audit.auditchange
	(keep=company_fkey dismiss_date auditor_resigned dismiss_name Engaged_auditor_name 
	dismissed_GC dismissed_disagree best_edgar_ticker); 
	if dismissed_disagree>0 and best_edgar_ticker>" "; 
run;

proc download data=sample2; 
run; 
endrsubmit; 


data audit.sample2; set sample2; run; quit; 

proc sort data=sample2; 
	by best_edgar_ticker dismiss_date; 
quit;
*733 obs;

proc report data=sample2(obs=30) windows; 
	column company_fkey best_edgar_ticker dismiss_date dismiss_name engaged_auditor_name; 
	define company_fkey / display; 
	define dismiss_date / display; 
	define dismiss_name / display format=$15.; 
	define engaged_auditor_name / format=$15.; 
	define best_edgar_ticker /display; 
quit;


*SOX Reporting Data example*;



rsubmit; 
data sample3; set audit.auditsox302
	(keep=company_fkey best_edgar_ticker sig_deficiency material_weakness is_effective
			noteff_acc_rule noteff_acc_reas_phr period_end_date_num); 
	if is_effective=0 and year(period_end_date_num)=2004 and best_edgar_ticker>' '; 
run;

proc download data=sample3; 
run; 
endrsubmit; 


/*data audit.sample3; set sample3; run; quit; */

proc sort data=sample3; by noteff_acc_rule; run; quit; 

proc sort data=sample3; 
	by best_edgar_ticker; 
quit; 
*258 observations;

proc report data=sample3 (obs=25) windows; 
	Column company_fkey best_edgar_ticker period_end_date_num sig_deficiency material_weakness noteff_acc_rule noteff_acc_reas_phr; 
	define company_fkey / display; 
	define period_end_date_num / display; 
	define sig_deficiency / display format=6.; 
	define material_weakness / display format=6.; 
	define noteff_acc_rule/ display format=6.; 
	define best_edgar_ticker /display ; 
	define noteff_acc_reas_phr / display format =$35.; 
run;



*******************************************
*********EXERCISE 1************************
******************************************;

RSUBMIT;
PROC SQL;
	CREATE TABLE audit_opinions
	AS SELECT company_fkey, fiscal_year_end_op, auditor_fkey,
		auditor_name, audit_op_key, auditor_city, auditor_state 
	FROM audit.auditopin 
	WHERE year(fiscal_year_end_op) = 2008
	;
QUIT;

PROC DOWNLOAD data=audit_opinions; RUN;

PROC SQL;
	CREATE TABLE audit_fees
	AS SELECT company_fkey, fiscal_year_ended, audit_fees
	FROM audit.auditfees
	WHERE year(fiscal_year_ended) = 2008
	;
QUIT;

PROC DOWNLOAD DATA=audit_fees; RUN;

ENDRSUBMIT;

*link the two tables together;
PROC SQL;
	CREATE TABLE answer1a
	AS SELECT a.*, b.*
	FROM audit_opinions as a LEFT JOIN audit_fees as b
	ON a.company_fkey=b.company_fkey AND a.fiscal_year_end_op =b.fiscal_year_ended
	;
QUIT;

*subtotal by auditor and city, then sort by same;
PROC SQL;
	CREATE TABLE answer1b
	AS SELECT auditor_city, auditor_name, 
		SUM(audit_fees) AS city_audit_fees
	FROM answer1a
	GROUP BY auditor_name, auditor_city
	ORDER BY city_audit_fees DESC
	;
QUIT;


*******************************************
*********EXERCISE 2************************
******************************************;

RSUBMIT;
PROC SQL;
	CREATE TABLE fee_change
	AS SELECT company_fkey, fiscal_year_ended, audit_fees, best_edgar_ticker 
	FROM audit.auditfees 
	WHERE year(fiscal_year_ended) GE 2000 AND
		year(fiscal_year_ended) LE 2006	;
QUIT;

PROC DOWNLOAD data=fee_change; RUN;

ENDRSUBMIT;

PROC SQL;
	CREATE TABLE fee_diff
	AS SELECT a.company_fkey, a.best_edgar_ticker, 
		b.audit_fees as Fees_2006 LABEL='Fees 2006',
		a.audit_fees as Fees_2000 LABEL='Fees 2000',
		b.audit_fees - a.audit_fees AS Fee_Increase,
		CALCULATED fee_increase/fees_2006 as Percent_Incr
	FROM fee_change as a, fee_change as b
	WHERE a.company_fkey =b.company_fkey AND 
		year(a.fiscal_year_ended) = 2000 AND
		year(b.fiscal_year_ended) = 2006
	ORDER BY Fee_increase DESC
	;
QUIT;




*******************************************
*********EXERCISE 3************************
******************************************;
RSUBMIT;
PROC SQL;
	CREATE TABLE fired_auditor
	AS SELECT company_fkey, best_edgar_ticker, dismiss_date,
		auditor_resigned, dismiss_name, subsidiary_name
	FROM audit.auditchange
	WHERE year(dismiss_date) GE 2000 AND 
		year(dismiss_date) LE 2006 AND
		auditor_resigned NE 1 
		;
QUIT;

PROC DOWNLOAD data=fired_auditor; RUN;

ENDRSUBMIT;

PROC SQL;
	CREATE TABLE firing_by_auditor
	AS SELECT dismiss_name, COUNT(dismiss_name) as firings
	FROM fired_auditor
	WHERE Subsidiary_name IS MISSING
	GROUP BY dismiss_name
	ORDER BY firings DESC
	;
QUIT;
