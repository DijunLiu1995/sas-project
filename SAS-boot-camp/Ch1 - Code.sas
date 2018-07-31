/****************************************************************************************************************
	PROJECT: 		SAS Camp 2018 - Day 1 Compustat
	DATE:			7/18/2018

****************************************************************************************************************/


/************************************************
*************************************************
	CH 1 - Compustat 
*************************************************
************************************************/

* Updated 7/18/18 by Nuria Seijas; 
* Updated 8/14/14 by Matthew Erickson;
* This is a master file that contains code for all Compustat example programs 
  and exercises in the AZDataGuideMar2012.pdf file with some modification.;

* Create a library where you will store all of your data - 8 characters or less;
LIBNAME saveData "C:\Users\nssei\Desktop\2018 SAS Camp\Day 1\Library";


* WRDS Login Code;
* Note the use of _prompt_;
%LET wrds = wrds-cloud.wharton.upenn.edu 4016;
OPTIONS COMAMID = TCP remote=WRDS;
SIGNON user=_prompt_;
* Or you can use:
	signon user = 'USERID' (your SAS user ID) password = 'PASSWORD' (your password)
	however, if you share SAS files, then you need to remember to erase your login data;


/************************************************
	Compustat - Example 1 - Annual Data
************************************************/

rsubmit;

* Data step is used to create a new data file from another file/dataset;
data compann; 									* New file name is compann;
	set comp.funda (keep= gvkey datadate cusip tic fyear fyr at sale ib sich
						  indfmt datafmt popsrc consol);
	if consol = 'C'; 							*Consol = 'C' selects the firms consolidated financial statements;
	if datafmt = 'STD'; 						*Datafmt = 'STD' is restated data;
	if indfmt = 'INDL'; 						*indfmt = 'INDL' selects firms that report their data in industry format;
	if popsrc = 'D'; 							*popsrc = 'D' selects domestic firms (USA, Canada & ADRs);

	if fyear GE 1995 and fyear LE 2005; 		*GE = Greater than or equal to, LE = Less than or equal to;
	if gvkey ne .;								*excludes observations without a gvkey; 

	*Some people use run and quit after every data or proc step. I use run after data steps and quit after proc statements.
		This is ultimately a matter of personal preference.;
run;


* Download the datafile to your work folder;
proc download data = compann;
run;

* Tell SAS to stop executing on the WRDS server;
endrsubmit;

* 130383; 


* Now, what you just did was tell SAS to create a new dataset containing ALL of Compustat.
	From this data set, you kept some variables (gvkey, datadate, etc....).
	Next, you discarded all observations no matching certain criteria.
	Finally, you downloaded the data.;

* While this works, it is slow. A much faster way to do things is like this:
	Create a new data set from compustat containing ONLY values that match criteria.
	Download the data.;


* Try the following code and see if it runs faster for you;
rsubmit;

data compannAlt;
	set comp.funda ( where = (consol = 'C' and datafmt = 'STD' and indfmt = 'INDL'
		                      and popsrc = 'D' and fyear GE 1995 and fyear LE 2005) 
	keep = gvkey datadate cusip tic fyear fyr at sale ib indfmt datafmt popsrc consol sich);
run;

proc download data = compannAlt;
run;

endrsubmit;

* First compare that you got the same number of observations in each dataset; 

* Now look in your log. Ignore the time of the proc download procedure and look just at
  the time for creating compann versus compAnnAlt. For Matt, this used to be an average of 30
  seconds faster to do it with a where statement - a 33% improvement on a minute and a half average.
  For Nuria, using IF was 21 second and using WHERE yielded 24 seconds. Your mileage may vary
  with your processing capabilities and how loaded the WRDS server is at the time you run your code;

* Normally, using IF is cleaner and easier to understand. But, when you are dealing with a BIG database
  (CRSP), WHERE statements may save you hours because they cut data earlier.;

* Saving the dataset to the library I specified; 
data saveData.compann; set compann; 
run;

* Recommend sorting prior to lagging as data may not be presorted;
proc sort data = compann;
	by gvkey fyear fyr;
quit;

data sample1; set compann;
	lag_gvkey = lag(gvkey); 					* Add the prior line's gvkey to the current line;
	lag_fyear = lag(fyear); 					* Add the prior line's fyear to the current line;
	lag_at = lag(at); 							* Add the prior line's assets to the current line;
	if gvkey NE lag_gvkey then lag_at = .; 		* Ensure that the lagged variable relates to the correct firm;
	if fyear-1 NE lag_fyear then lag_at = .; 	* Ensure that there is only a one year difference (e.g. no missing year).;
	avg_at = (at + lag_at)/2; 					* Create a new variable, AVG_AT;
	if avg_at > 0 then ROA = ib / avg_at; 		* Create a new variable, ROA;
	drop indfmt datafmt popsrc consol; 			* Drop unnecessary variables;
run;

proc print data = sample1(obs=20);
run;

* Now, is what we have reasonable? Let's investigate our data using proc univariate;
* But first, what would you expect for an "average" ROA?;
proc univariate data=sample1;
	var ROA;
run;

*Sort the data by ROA so we can dig deeper if we want to do so.;
proc sort data=sample1;
	by ROA;
quit;

* Looks like we have some outliers in the data. This can really mess up a regression.
  Open up the sorted data file - do you notice a pattern as to the types of firms that have extreme ROAs?
  Later on, we will talk more about why this happens and how to potentially fix this problem.;





/************************************************
	Compustat - Example 2 - Quarterly Data
************************************************/

* Tell SAS to work on the WRDS server;
rsubmit;

data compqtr; 									*New file name is compqtr;
	set comp.fundq (keep= gvkey datadate cusip tic fyearq rdq dlttq 
						  indfmt datafmt popsrc consol); 				
						  *Note this is comp.fundq not comp.funda. Note how variables often end in q for this dataset.;
	if fyearq = 2006;
	if consol = 'C'; 							
	if datafmt = 'STD'; 					
	if indfmt = 'INDL'; 						
	if popsrc = 'D'; 							
run;
* We pulled 11 variables; 

* Note that the ‘comp.fundq’ dataset does not have a sich variable, we have to get the historical sic from another table;
data compsic; 									* New file name is compsic;
	set comp.company (keep= gvkey sic);
	if sic GE 3000 and sic LE 4000; 			* Selects a specific SIC code range;
run;
* This has 2 variables; 

* Merge the two files from Compustat to create a new file, compmerged;
* Proc sql is commonly used for merging datasets.;
proc sql;
	create table compmerged
	as select a.*, b.*
	from compqtr as a 
    inner join compsic as b
	on a.gvkey = b.gvkey;  						* The two files are matched to gvkey;
quit;
* How many variables in the merged file? Why?;
* Gvkey; 

* What did merging keep? Only observations with an SIC code as specified above. Why?....;

* Here is what the above code means:
create a new table called compmerged
gather data from two tables, which are going to be called a and b. a.* and b.* mean everything in both tables
use compqtr and call it table a. inner join this table (more on that in a moment) with the compsic table, which we will call table b
merge whenever the gvkey in both tables are equal.;

* There are 4 primary kinds of joins: left, right, inner, and outer.
	We tend to use left join 90%+ of the time and inner join <10% of the time.
	Right or outer join only a few rare times.;
* Let's draw out on the whiteboard what each type of join accomplishes.;

* Download the datafile to your work folder;
proc download data = compmerged;
quit;

* Tell SAS to stop executing on the WRDS server;
endrsubmit;

* Remember to close the dataset after you inspect it and before you try to do another step to manipulate it; 

* We recommend using a different file name (creating a new dataset) so that if you accidently make a mistake,
  you don't have to download the data again;
data example2; set compmerged;
	if missing(datadate) then delete; 			* Drop firms that are missing the datadate variable;
	drop indfmt datafmt popsrc consol; 			* Drop unnecessary variables;
run;

proc print data = example2(obs=15);
run;
* Printing is optional. You can also open the table and inspect;
 

* Discuss alternate code in handbook with renameing the gvkey variable; 

data saveData.example2; set example2;
run;



/************************************************
	Compustat - Example 3 - Global Data
************************************************/

* This is complicated code. Skip this if we are running low on time.;

rsubmit;

data intlfirms;
	set comp.g_funda(keep=gvkey conm fic curcd sale fyear 
                          indfmt datafmt popsrc consol);
	if fyear= 2006; 							* Select only firms with FY 2006;
	if consol='C';
	if datafmt='HIST_STD'; 						* Selects the first reported annual and interim data, not restated;
	if indfmt='INDL';
	if popsrc='I'; 								* Selects international firms (Non-USA, non-Canadian, non-ADRs);
	if missing(sale) then delete;
run;

proc download data=intlfirms;
quit;

endrsubmit;



* The CARDS statement creates observations.
* Here you are using it to specify the date when you want exchange rates.;
data exchrate_dates;
	format exch_date date9.;
	input exch_date yymmdd10.;
CARDS;
20061231
;
run;

* The handbook creates the above dataset on the WRDS server. 
  We are creating it locally to see what it does, but then we have to upload it; 
rsubmit;
proc upload data = exchrate_dates;
run;

* comp.g_exrt_mth is the exchange rate dataset on Compustat;
* 	fromcurm = From currency - Always GBP
	tocurm = To currency
	exratm = Exchange rate;
proc sql;
	create table exchrates
	as select x.*, s.*
	from comp.g_exrt_mth(keep=fromcurm tocurm exratm datadate) as x
	inner join exchrate_dates as s
	on s.exch_date = x.datadate;
quit;

proc print data=exchrates (obs=5);
run;

proc download data=exchrates;
run;
endrsubmit;


data gbp_to_usd;
	set exchrates(keep=tocurm exratm datadate);
	if tocurm='USD'; 							* Keep only exchange rates for USD;
	rename exratm=to_usd;						* Renaming the exratm variable (not the title); 	
run;

*add in the gbp_usd exchange rate;
proc sql;
	create table d_exchrates
	as select x.*, s.*
	from exchrates (keep=tocurm fromcurm exratm exch_date) as x
	left join gbp_to_usd (keep=to_usd datadate) as s
	on x.exch_date = s.datadate;
quit;

*Also add the local currency to gbp exchange rate;
proc sql;
	create table d_intlfirms
	as select x.*, s.*
	from intlfirms as x
	left join d_exchrates (keep=tocurm exratm to_usd) as s
	on x.curcd = s.tocurm;
quit;

*Convert local sales to USD.;
data d_intlfirms;
	set d_intlfirms;
	dollarsales=(((sale/exratm)*to_usd)/100); * Convert sales to GBP, and then convert to USD and scale it.;
run;
* Note order of operations; 
* NS: Calculate the first 2 manually to verify; 

proc sort data=d_intlfirms;
	by descending dollarsales;
run;

proc print data=d_intlfirms(obs=20);
	var conm curcd fic sale exratm to_usd dollarsales; 
run;



/************************************************
	Compustat - Example 4 - Execucomp 
************************************************/

rsubmit;
data compsample;
	set comp.anncomp
		(keep= cusip coname ticker exec_fullname year salary 
			   bonus stock_awards option_awards age title);
	if year = 2006;
run;

proc download data=compsample;
run;

endrsubmit;

*Calculate cash equity, and tota compensation;
data compsample; set compsample;
  	cash_comp = salary + bonus;
  	equity_comp = stock_awards + option_awards;
  	total_comp = cash_comp + equity_comp;
run;

proc sort data = compsample;
	by descending total_comp;
run;

proc print data=compsample(obs=10);
   var ticker coname cash_comp equity_comp total_comp exec_fullname;
run;

* Note that BAC2=Merrill Lynch;
* Added coname variable to the proc print statement; 




/************************************************
	Compustat - Exercise 1
************************************************/

rsubmit;
data CH1_EX1_RD;
	set comp.funda (keep=gvkey fyear conm xrd revt sich indfmt datafmt popsrc consol);
						 * revt is revenue total; 
						 * xrd is R&D expense; 
	if fyear=2006;
	if indfmt='INDL'; 
	if datafmt='STD'; 
	if popsrc='D'; 
	if consol='C'; 
	if sich = . then delete;
	*Set R&D to 0 if missing - general convention;
	if xrd=. then xrd=0;
	RD_Sales_Ratio = xrd / revt;
	if RD_Sales_Ratio <= .05 then delete;
	if RD_Sales_Ratio = . then delete;
	drop indfmt datafmt popsrc consol;
run;

proc download data = CH1_EX1_RD;
run;

endrsubmit;

proc sort data=CH1_EX1_RD;
	by sich;
run;

*We haven't looked at proc freq before - check out your handout/google;
proc freq data=CH1_EX1_RD;
	tables sich;
run;

proc univariate data = CH1_EX1_RD;
	var RD_Sales_Ratio;
run;



/************************************************
	Compustat - Exercise 2
************************************************/

rsubmit;
data CH1_EX2_PIQ;
	set comp.fundq ( where = (fyearq = 2006) 
					 keep =	gvkey fyearq rdq datadate fqtr fyr conm piq txtq cshoq prccq 
							indfmt datafmt popsrc consol);
	if indfmt = 'INDL'; 
	if datafmt = 'STD'; 
	if popsrc = 'D'; 
	if consol = 'C'; 
	if piq > 0; 								* PIQ = Pretax Income;
	if piq = . then delete;
	if txtq = . then delete; 					* txtq = Income Taxes Total;
	if txtq <= 0 then delete;
	ETR = txtq / piq;							* ETR - effective tax rate; 
	if cshoq = . then delete;					* CSHOQ - common shares outstanding; 
	if cshoq <= 0 then delete;
	if prccq = . then delete;					* PRCCQ - price close - quarter; 
	if prccq <= 0 then delete;
	*You can also use the mkvaltq variable but WARNING - this isn't well populated early on in Compustat.;
	MVE = cshoq * prccq;
	drop indfmt datafmt popsrc consol;
run;

* This time, we pull sich from comp.funda. Why? It includes a fyear to match on.;
* This is more accurate than the first way we did it.;
proc sql;
	create table CH1_EX2_SIC as select a.*, b.sich
	from CH1_EX2_PIQ as a, comp.funda as b
	where (a.gvkey = b.gvkey) and (a.fyearq = b.fyear);
quit;

proc download data = CH1_EX2_SIC;
quit;
endrsubmit;

* Talk about role of nodupkey in proc sort.;
* The NODUPKEY option checks for and eliminates observations with duplicate BY variable values. If you specify this
option, PROC SORT compares all BY variable values for each observation to those for the previous observation
written to the output data set. If an exact match using the BY variable values is found, the observation is not written to
the output data set.; 
proc sort nodupkey data = CH1_EX2_SIC out=CH1_EX2_SIC_2 ;
	by gvkey fyearq fqtr cshoq;
run;
* Check to see how many observations you lost; 

data CH1_EX2_SIC_3;
	set CH1_EX2_SIC_2;
	if sich = . then delete;
run;

* You must sort data before ranking it.;
proc sort data=CH1_EX2_SIC_3;
	by ETR;
run;

* Compute the ranks of the valuesof numeric variables - see handout #2; 
proc rank data=CH1_EX2_SIC_3
	OUT = CH1_EX2_Rank
	TIES = low
	groups = 10;
	*ties=low, high, or dense;
	*groups=number of groups - starts at 0 not 1!;
	var ETR;
	*Rank on ETR;
	ranks ETRrank;
	*Call the rank variable rankETR;
run;

* Since we divided into 10 groups, the observations with ETRrank of value 0 will represent the lowest 10% of tax rates; 
data CH1_EX2_Low_ETR;
	set CH1_EX2_Rank;
	if ETRrank = 0;
run;
* Are you left with 10% of the observations from the full dataset?; 

* Let's check concentration by industry; 
proc freq data = CH1_EX2_Low_ETR;
	table sich;
run;

* What is the mean, median, 25% decile, and 75% decile of the market value of these low tax rate firms?; 
proc means n mean median min p1 p5 p25 p50 p75 p95 p99 max data = CH1_EX2_Low_ETR;
	var mve;
run;




/************************************************
	Compustat - 
Exercise 3
************************************************/

rsubmit;

data CH1_EX3;
	set comp.g_funda(keep = gvkey conm fic curcd sale fyear datadate 
							indfmt datafmt popsrc consol);
	if fyear ge 2005;							* For sales growth we will need 2006 beginning and ending numbers;
	if fyear le 2006;
	if consol='C';
	if datafmt='HIST_STD'; 						
	if indfmt='INDL';
	if popsrc='I'; 								
run;

proc download data = CH1_EX3;
run;

endrsubmit;

proc sort data = CH1_EX3;
	by gvkey datadate;
run;

data CH1_EX3_SG;
	set CH1_EX3;
	lagsale = lag(sale);
	laggvkey = lag(gvkey);
	*Don't need a lag year check since we only have two years.;
	if laggvkey ne gvkey then lagsale = .;
	chgsale = ((sale-lagsale)/lagsale);
	if chgsale ne .;
run;

proc sort data = CH1_EX3_SG;
	by fic;
run;

*WARNING - if you run a proc means/reg/etc... BY a variable, make sure to sort
	BY that same variable first. Otherwise, your results will be wrong but this
	may not be apparent at first.;
proc means data = CH1_EX3_SG n mean clm min p1 p5 p25 median p75 p95 p99 max;
	var chgsale;
	by fic;
	output out = CH1_EX3_AVG;
run;




/************************************************
	Compustat - Exercise 4
************************************************/

rsubmit;
data CH1_EX4_EC;
	set comp.anncomp (keep = gvkey ticker cusip salary
							 bonus EXEC_FULLNAME CONAME year);
	if year ge 2005 and year le 2006;
	cashcomp = salary + bonus;
run;

proc download data = CH1_EX4_EC;
quit;
endrsubmit;

proc sort data=CH1_EX4_EC;
	by gvkey year;
run;

proc sql;
	*Another way to create a lagged variable.;
	create table CH1_EX4_Cash_Comp
	as select a.*, b.cashcomp as lag_cashcomp
	from CH1_EX4_EC as a 
	left join CH1_EX4_EC as b
	on (a.EXEC_FULLNAME = b.EXEC_FULLNAME)
	and (a.gvkey = b.gvkey) and (a.year = b.year + 1);
quit;

data CH1_EX4_Cash_Comp;
	set CH1_EX4_Cash_Comp;
	chgcash = cashcomp - lag_cashcomp;
	percentage_raise = chgcash / lag_cashcomp;
run;

data CH1_EX4_Cash_Comp_2;
	set CH1_EX4_Cash_Comp;
	if year = 2006;
	if chgcash =. then delete;
	if percentage_raise =. then delete;
run;


* Alternatively, one you get more familiar with coding, you can write more concise steps; 
* The above 2 steps could be written witin 1;
data CH1_EX4_Cash_Comp_alt;
	set CH1_EX4_Cash_Comp;
	if year = 2006;
	chgcash = cashcomp - lag_cashcomp;
	if chgcash =. then delete;
	percentage_raise = chgcash / lag_cashcomp;
	if percentage_raise =. then delete;
run;
* Do you end up with the same number of observations?; 

proc sort data=CH1_EX4_Cash_Comp_2;
	by descending percentage_raise;
run;

proc print data = CH1_EX4_Cash_Comp_2 (obs=10);
run;

proc rank data = CH1_EX4_Cash_Comp_2
	OUT = CH1_EX4_Ranked
	TIES = low
	groups = 10; 
	var percentage_raise;
	ranks raiserank;
run;

data CH1_EX4_High_Rollers;
	set CH1_EX4_Ranked;
	if raiserank = 9;
	*note = 9  is the highest since ranks run from 0-9;
run;
* Do you end up with about 10% of the observations?;

proc means mean data = CH1_EX4_High_Rollers;
	var percentage_raise;
run;
* But investiagte this further - as with ROA are outliers skewing things?
* Does the mean percent really even have any relevancy here?;



****TUTORIAL ON SAVING DATA****;

data saveData.yourtablename; set CH1_EX4_High_Rollers;
run;










/************************************************
*************************************************
	ERROR - Too Many PC-SAS Connections  
*************************************************
************************************************/

* Sometimes you will get this error in your log when you don't use the signoff command;
* Follow the instructions therein to fix it; 

***** ERROR ***** ERROR ***** ERROR ***** ERROR ***** ERROR *****
*                                                               *
* You currently have too many PC-SAS connections running.       *
* Please disconnect one or more of the existing connections     *
* before beginning additional sessions.                         *
*                                                               *
* You can view or stop your currently-connected PC-SAS sessions *
* via the WRDS website at https://wrds-web.wharton.upenn.edu.   *
* Click the "Your Account" link at the top right of the page,   *
* then click the "Running Queries" link in the menu.            *
* You can see your running PC-SAS sessions under "PC-SAS Jobs", *
* and end them with the "Kill" link.                            *
*                                                               *
* If you have any questions or concerns, please contact us at   *
* wrds-support@wharton.upenn.edu.                               *
*                                                               *
***** ERROR ***** ERROR ***** ERROR ***** ERROR ***** ERROR *****


