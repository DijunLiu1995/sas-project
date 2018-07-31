/*RUSS SIGN ON AND DIRECTORIES*/
%LET wrds = wrds-cloud.wharton.upenn.edu 4016;
OPTIONS comamid = TCP remote=wrds;
SIGNON username = _prompt_;
LIBNAME c_drive 'C:\Users\Russ Hamilton\Documents\SAS data files\SAS camp 16';


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

*******************************************
*page 21 example--summary file
******************************************;

data sample;
input oftic $ 1-6 year $8-15;
eyear=input(year, yymmdd8.);
cards;
MSFT  20051231
DELL  20051231
GE    20051231
;

rsubmit;
proc upload data=sample;

proc sql;
	create table forecast 
	as select
	A.ticker, A.cusip, B.oftic, A.statpers, /*A.statpers,*/ A.fpedats, A.meanest, A.actual, A.anndats_act
	from ibes.statsum_epsus as A, sample as B
	where (A.oftic = B.oftic) and (year(B.eyear)=(year(A.fpedats))) and A.fpi='1';
quit;
proc download data=forecast; run;

endrsubmit;

proc print data =forecast;
  var oftic statpers fpedats meanest actual anndats_act;
  format anndats_act YYMMDDn8.;
run;
quit;


********************************************************
*LET'S DO THAT AGAIN, BUT USING EXCEL INSTEAD OF "CARDS"
TO GET THE DATA INTO SAS;
*******************************************************;

*preview: How does SAS deal with dates?  Base Date =1/1/1960

*first, create the excel file:
oftic	year
MSFT	12/31/2005
DELL	12/31/2005
GE	    12/31/2005

*second, import the excel file into a SAS file called 'sample_excel';
*...FILE...IMPORT DATA...;


*third, rerun the old program (but remember that we don't have 
the eyear variable anymore, so tweak the program slightly);

rsubmit;
proc upload data=sample_excel;

proc sql;
	create table forecast 
	as select
	A.ticker, A.cusip, B.oftic, A.statpers, A.statpers, A.fpedats, A.meanest, A.actual, A.anndats_act
	from ibes.statsum_epsus as A, sample_excel as B
	where (A.oftic = B.oftic) and (year(B.YEAR/*here is the change*/)=(year(A.fpedats))) and A.fpi='1';
quit;
proc download data=forecast; run;

endrsubmit;

proc print data =forecast;
  var oftic statpers fpedats meanest actual anndats_act;
  format anndats_act YYMMDDn8.;
run;
quit;


***************************************************
**Example on page 25--detail file
*************************************************;

data sample1;
input oftic $ 1-6 year $8-15;
eyear=input(year, yymmdd8.);
cards;
MSFT  20051231

;

rsubmit;
proc upload data=sample1;

proc sql;
	create table forecast as select
	A.ticker, A.cusip, B.oftic, A.actdats, A.estimator, A.analys, A.value, A.actual, A.anndats_act, a.fpedats
	from ibes.det_epsus as A, sample1 as B
	where (A.oftic = B.oftic) and (year(B.eyear)=(year(A.fpedats))) and A.fpi='1';
quit;
proc download data=forecast; run;

endrsubmit;



*sort data by analyst and date;
proc sort data = forecast;
by analys actdats;
run; 

*this step keeps only the last forecast for each
analyst for each date;
data forecast1;  set forecast;
by analys actdats;
if last.analys;
run; quit;


*another way to do this, using trusty PROC SQL!;
PROC SQL;
	CREATE TABLE forecast1_alt
	AS SELECT *
	FROM forecast
	GROUP BY analys
	HAVING ACTDATS = max(ACTDATS)
	;
QUIT;




*computes the number of days the forecast is from 
the earnings announcement date--longer time periods
are harder to predict;
data forecast2; set forecast1;
	AV_age = ANNDATS_ACT - ACTDATS;
run; 









***********************************************
*EXERCISE 1;
*********************************************;
rsubmit;

data ibis2; set ibes.statsum_epsus;
	if year(fpedats) = 2005 ;
	if fpi ='1' /*current year, annual period*/;
    surprise =abs(actual - meanest);
	age = ANNDATS_act - statpers;
	if surprise = . then delete;

	
run;
proc download data=ibis2; run;

endrsubmit;
*51,658 observations;

*let's just look at estimates that are created less than 30
days before the earnings announcment date;
data ibis3;
	set ibis2;
	if age<30;
run;
*5601 observations;


PROC reg
	data=ibis3;
	model surprise  = numest;
	run;
*hard to see much here--too many 
	extreme values;


*remove extreme values before performing analysis;
%include 'C:\Users\Russ Hamilton\Documents\My SAS Files\9.4\macros\macros.sas';
%WT(data=ibis3, out=ibis3W, 
	 
	vars=surprise,
	type = t, 
	pctl = 1 99, 
	drop = n);
run;

PROC reg
	data=ibis3w;
	model surprise  = numest;
	run;
*now we can see the results-- negative
	coefficient means more analysts mean
	smaller earnings surprises;




*********************************
Exercise 3
********************************;

rsubmit;

data forecast; set ibes.det_epsus;
	keep 
	ticker cusip oftic actdats estimator analys value actual anndats_act fpedats;
	if year(fpedats) ge 2000 and year(fpedats) le 2006;
	if fpi ='1'; 
run;
proc download data=forecast; run;

endrsubmit;
*991,488 observations;


* we need the LAST forecast for each analyst for each firm for each period;
proc sort data = forecast;
by cusip fpedats analys actdats;
run; quit;
*991,488 observations;

data forecast1;  set forecast;
by cusip fpedats analys actdats;
if last.analys;
run; quit;
*280,038 observations remaining;


data forecast2; set forecast1;
	AV_age = ANNDATS_ACT - ACTDATS;
	if AV_age = . then delete;
	year = year(fpedats);
run; quit;
*269,976 observations remaining;


proc sort data=forecast2; by year;
run;
*269,976 observations remaining;



proc means data = forecast2; output out = age;
var AV_age;
by year;
run; quit;

data age_mean; set age;
if _STAT_ = 'MEAN';
run;





***or, using our favorite, PROC SQL, after the data download;
PROC SQL;
	CREATE TABLE forecast1_alt
	AS SELECT DISTINCT *, ANNDATS_ACT - ACTDATS AS AV_age, year(fpedats) as Year
	FROM forecast
	GROUP BY cusip, fpedats, analys
	HAVING ACTDATS = max(ACTDATS) 
	
	;
QUIT;
*281,545 records;

PROC SORT data=forecast1_alt NODUPKEY; BY cusip fpedats analys actdats; RUN;
*there are 707 observations with identical cusip fpedats analys actdats.  Hmmm....;
*280,838 records remaining;

PROC SQL;
	CREATE TABLE forecast2_alt
	AS SELECT *
	FROM forecast1_alt
	WHERE AV_age IS NOT MISSING
	;
QUIT;
*269,977 records remaining;


PROC SQL;
	CREATE TABLE Age_mean_alt
	AS SELECT year, mean(av_age) as mean_age
	FROM forecast2_alt
	GROUP BY year
	ORDER BY year
	;
QUIT;




************************************
*EXERCISE 4;
***********************************;

rsubmit;
data ibes; set ibes.det_epsus;
	surprise = abs(actual - value);
	if surprise = . then delete;
	if year(fpedats) = 2005;
	if fpi='1';
	keep 
	ticker cusip oftic actdats estimator analys value actual fpi fpedats anndats_act surprise;
run;
proc download data = ibes; run;
endrsubmit;
*154,041 records;

*the below steps eliminate duplicate analyst forecasts for the same quarter, taking only the last analyst estimate;
proc sort data = ibes;
by cusip fpedats analys actdats;
run; quit;

data forecast1;  set ibes;
by cusip fpedats analys actdats;
if last.analys;
run; 
*39,457 records remaining;


*compute analyst performance;
proc sql;
	create table analy_summary
	as select analys, avg(surprise) as avg_surprise
	from forecast1
	group by analys
	order by avg_surprise
	;
quit;
*4,499 records;

*determine number of companies following;
PROC SQL;
	CREATE TABLE followings
	AS SELECT analys, count(cusip) as follows
	FROM ibes
	GROUP BY analys
	;
QUIT;
*4,499 records;

*put the two tables together;
PROC SQL;
	CREATE TABLE final_table
	AS SELECT a.*, follows
	FROM analy_summary as a, followings as b
	WHERE a.analys =b.analys
	;
QUIT;
*4,499 records;


*remove extreme values before performing analysis;
%include 'C:\Users\Russ Hamilton\Documents\My SAS Files\9.4\macros\macros.sas';
%WT(data=final_table, out=final_tablew, 
	 
	vars=avg_surprise,
	type = t, 
	pctl = 1 99, 
	drop = n);
run;


PROC REG data=final_tablew;
	model avg_surprise = follows;
	RUN;
*so there seems to be a positive relationsihp between 
	the number of firms followed and the average forecast
	error, based on this simple model. 


