/****************************************************************************************************************
	PROJECT: 		SAS Camp 2018 - Day 2 CRSP
	DATE:			7/20/2018

****************************************************************************************************************/

/************************************************
*************************************************
	CH 2 - CRSP 
*************************************************
************************************************/

* Updated 7/18/18 by Nuria Seijas; 
* Updated 8/14/14 by Matthew Erickson;


*Recognize these steps yet?;
LIBNAME saveData "C:\Users\nssei\Desktop\2018 SAS Camp\Day 1\Library";
*%include "C:\Users\nssei\Desktop\2018 SAS Camp\Day 1\macros.sas";
%LET wrds = wrds-cloud.wharton.upenn.edu 4016;
OPTIONS COMAMID = TCP remote=WRDS;
SIGNON user=_prompt_;


/*********************************************************
	CRSP - Printing contents of a dataset; 
*********************************************************/

rsubmit; 

proc contents data=crsp.dsf; 
run; 

endrsubmit; 





/***********************************************************
	CRSP - Example 1 - Getting returns around an event day
***********************************************************/

rsubmit;
*%let creates a macro variable (akin to a constant).
	If you decide you wnat to change things to 180 days before,
	you can update this in one place only and be done.;
%let day_before = 61;
%let day_after = 2;

data events;
	format date0 date1 date2 date9.;
	input cusip $8. date0 yymmdd10.;
	*Date one is a min date and date 2 is a max date.;
	date1 = date0 - &day_before;
	date2 = date0 + &day_after;

*specify specific cusip and event date manually via cards.;
CARDS;
45920010 19980102
59491810 20010405
24702R10 20041121
;
run;

proc print data = events;
run;

proc sort data = events;
	by cusip date1;
run;

proc sql;
	create table esfx
	as select a.*, b.*
	from events as a
	left join crsp.dsf (keep = date cusip prc vol ret) as b
	on (a.cusip = b.cusip) and (a.date1 <= b.date <= a.date2);
quit;

proc download data = esfx;
run;
endrsubmit;

proc sort data = esfx out = saveData.esfx;
	by cusip date;
run;

*What did invoking saveData.esfx do? Open up the saveData path 
 on your machine.;
*You can see SAS stored a dataset there. This is pretty handy 
 for working on projects across multiple days. Usually, when 
 you close SAS, your datasets are deleted. Using a saveData 
 location lets you store these.;

proc print data = saveData.esfx (obs = 20);
run;

*Would you expect each of our 3 stocks to have the same number 
 of price observations? Let's try a simple proc means to investiage;
proc means data=esfx n;
	var date;
	by cusip;
run;

*Why isn't n constant?
	It goes back to how we specified the number of days. Stocks 
    only trade on non-holiday weekdays. So, if you specify a fixed 
    number of days but don't specify weekdays only, SAS counts total days.
	As a result, each of these event days has a different number of trading days in the 61 calendar days
		prior to the event.
	This isn't a big deal for us this time, but it can be a major problem depending on what you are
		trying to do.;



/***********************************************************
	CRSP - Example 2 - Event Data
***********************************************************/

rsubmit;
data sample;
	format date1 date2 date9.;
	input cusip $8. date1 yymmdd10. date2 yymmdd10.;

cards;
45920010 19800101 20071231
59491810 19800101 20071231
24702R10 19800101 20071231
;
run;

proc print data = sample;
run;

proc sort data = sample;
	by cusip date1;
run;

* Take a look at the dsedist file in the WRDS website. What are the variables?; 
* Take a look at the information for distcd, why are we looking for 5xxx?; 
proc sql;
	create table stkdiv
	as select a.*, b.*
	from sample as a
	left join crsp.dsedist (keep = cusip distcd facshr dclrdt paydt) as b
	on (a.cusip = b.cusip) and (a.date1 <= b.dclrdt <= a.date2)
	where distcd > 4999 and distcd < 6000;
quit;

proc download data = stkdiv;
run;
endrsubmit;

proc sort data = stkdiv out = saveData.stkdiv;
	by cusip dclrdt;
run;

proc print data = saveData.stkdiv;
run;




/***********************************************************
	CRSP - EXERCISE 1
***********************************************************/

rsubmit;
*Get all company names and cusip's.;
data crspcompanies;
	set crsp.stocknames (keep=comnam cusip);
run;

*Sort and remove any duplicate entries.;
proc sort nodupkey data=crspcompanies;
	by comnam cusip;
run;

*Download file.;
proc download data=crspcompanies;
run;
endrsubmit;

* One option to look for the cusips for a company for which you
  may not know the exact name of is the following. The % matches
  any sequence of zero or more characters. These patterns can 
  appear before, after, or on both sides of characters that you 
  want to match. The LIKE condition is case-sensitive.;
proc sql;
	create table investigate as
	select * from crspcompanies 
	where  comnam like ('%MERCK%')
 		or comnam like ('%JOHNSON%')
		or comnam like ('%PFIZER%');
quit; 


* Once you know get the actual company names, you can use this to print; 
proc print data= crspcompanies; 
	where comnam EQ "MERCK & CO INC" or 
		  comnam EQ "JOHNSON & JOHNSON" or 
	      comnam EQ "PFIZER INC"; 
run; 


* Alternatively, open up your raw crspcompanies, then in the little
  white bar next to the check mark, type in the following and hit enter:
  where comnam like ('%MERCK%')
  This is a sql command.; 



*
58933Y10 MERCK
47816010 J&J
71708110 PFIZER;


/***********************************************************
	CRSP - EXERCISE 2
***********************************************************/

data event;
	format date1 date2 date9.;
	input cusip $8. date1 yymmdd10. date2 yymmdd10.;

CARDS;
58933Y10 20040101 20061231
47816010 20040101 20061231
71708110 20040101 20061231
;
run;

rsubmit;
proc upload data=event;
quit;

proc sql;
     create table pharmareturns
     as select a.*, b.*
     from event as a
     left join crsp.msf (keep= date cusip prc vol ret) as b
     on (a.cusip = b.cusip) and (a.date1 <= b.date <= a.date2);
quit;

proc download data=pharmareturns;
quit;
endrsubmit;



/* or an alternative way of doing it */
rsubmit;
data pharmareturns_2;
	set crsp.msf (keep = date cusip prc vol ret);
	where (2004 <= year(date) <= 2006)
		and (cusip = "58933Y10" or cusip = "47816010"
			or cusip = "71708110");
run;

proc download data=pharmareturns_2;
quit;
endrsubmit;




/***********************************************************
	CRSP - EXERCISE 3
***********************************************************/

data divsample; 
	format date1 date2 date9.;
	input cusip $8. date1 yymmdd10. date2 yymmdd10.;

CARDS; 
58933Y10 20040101 20061231
47816010 20040101 20061231
71708110 20040101 20061231
;
run;

rsubmit;
proc upload data=divsample;
quit;
endrsubmit;

rsubmit;
proc sql;
     create table pharmadiv
     as select a.*, b.*
     from divsample as a 
     left join crsp.dse (keep= date cusip divamt) as  b
     on a.cusip = b.cusip and (a.date1 <= b.date <= a.date2);
quit;

data pharmadiv;
	set pharmadiv;
	if divamt = . then delete;
run;

proc download data=pharmadiv;
quit;
endrsubmit;

proc sort nodupkey data=pharmadiv;
by cusip date;
quit;



/* or an alternative way of doing it */
rsubmit;
data pharmadiv_2;
	set crsp.dse (keep= date cusip divamt);
	where (2004 <= year(date) <= 2006)
		and (cusip = "58933Y10" or cusip = "47816010"
			or cusip = "71708110")
		and (divamt ne .);
run;





*Get Shrout; 
proc sql;
	create table pharmadiv_2a 
	as select distinct a.*, b.SHROUT
	from pharmadiv_2 a left join crsp.dsf b
	on (a.cusip = b.cusip) and (a.date = b.date);
quit;

proc download data=pharmadiv_2a;
quit;
endrsubmit;

*Create a variable for total cash dividends; 
data pharmadiv_2a;
	set pharmadiv_2a;
	total_div = SHROUT * divamt;
	year = year(date);
run;

proc sort data = pharmadiv_2a;
	by cusip year;
quit;

*Get total cash dividends paid each year; 
proc means data = pharmadiv_2a sum;
	by cusip year;
	var total_div;
	output out = saveData.pharmadiv_2a sum(total_div)=/autoname;
quit;





/***********************************************************
	CRSP - EXERCISE 4
***********************************************************/

*Only select needed CUSIPs.;

rsubmit;
data exc_4_returns;
	set crsp.dsf (keep = date cusip ret);
	where (year(date) = 2006)
		and (cusip = "58933Y10" or cusip = "47816010"
			or cusip = "71708110");
run;

proc download data=exc_4_returns;
quit;
endrsubmit;

proc sql;
	create table exc_4_compreturns
	as select distinct cusip, exp(sum(log(1+ret)))-1 as comp_ret, 
					   n(ret) as n_obs
	from exc_4_returns
	group by cusip;
	*Note the exp(sum(log(1+ret)))-1 code does continuous compounding.
		Remember this for future use.;
quit;





/************************************************
	CRSP - CRSP_Compustat link table  
************************************************/

*Bring down crsp_compustat merged database*;

rsubmit;
data link;
	set crsp.ccmxpf_linktable;
	keep gvkey lpermno linkdt linkenddt usedflag linkprim;
run;

proc download data = link;
quit;
endrsubmit;






* Merge link table with compustat data*;
proc sql;
	create table sample1
	as select a.*, b.lpermno as permno
	from ????? as a left join crsp.CCMXPF_LNKHIST
		(where=(LINKTYPE in ('LC', 'LU') and linkprim in ('P','C'))) as b
	on a.gvkey = b.gvkey and ((b.linkdt <= a.datadate) or
		(b.linkdt = .B)) and ((a.datadate <= b.linkenddt) or
		(b.linkenddt = .E));
quit;

*Discuss how to use link table to match gvkey to permno
 This is an important concept!;

proc sort data = comp_link nodupkey;
	by gvkey fyear;
quit;






rsubmit;
proc contents data = crsp.dsf;
quit;
proc contents data = comp.funda;
quit;
endrsubmit;

*Note that there are over 85 million observations in this data set versus 700 thousand for compustat.
	As a general rule of thumb, efficient coding matters much more in CRSP than compustat.;
