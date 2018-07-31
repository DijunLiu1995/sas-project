**********************************************************
*
*  IBES Exercises
*
**********************************************************;

* Problem 1;


%let wrds = wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=wrds;
signon username=_prompt_;
Libname rwork slibref=work server=wrds;

rsubmit;

data ibis2; 
	set ibes.statsum_epsus;
	if year(fpedats) = 2005;
	if fpi = '1'; /* current year, annual period */
	surprise = abs(actual - meanest);
	age = anndats_act - statpers;
	if surprise = . then delete;
run; 

proc download data = ibis2;
run;

endrsubmit;


data ibis3;
	set ibis2;
	if age < 30;
run;



proc reg
	data = ibis3;
	model surprise = numest;
run;

%include 'C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp\MacroRepository.sas';

%WT(data = ibis3, out=ibis4, vars = surprise, type = t, pctl = 1 99, drop = n)




proc reg data = ibis4;
	model surprise = numest;
run;









* Exercise 2;


rsubmit;

data forecast;
	set ibes.det_epsus;
	keep fpedats actual meanest fpi ticker cusip oftic actdats estimator analys value actual anndats_act;
	if year(fpedats) >= 2000 and year(fpedats) <= 2006;
	if fpi = '1';
run;


proc download data = forecast; run;

endrsubmit;


proc sort data = forecast;
by cusip fpedats analys actdats;
run;

quit;


data forecast1;
	set forecast;
	by cusip fpedats analys actdats;
	if last.analys;
	run;

quit;




data forecast2;
	set forecast1;
	AV_age = anndats_act - actdats;
	if av_age = . then delete;
	year = year(fpedats);
run;

proc sort data = forecast2; by year;
run;

proc means data = forecast2; output out = age;
	var AV_age;
	by year;
run;

data age_mean; set age;
	if _STAT_ = 'MEAN';
run;


* Or proc sql;

proc sql;

	create table	forecast1_alt
	as select distinct *, anndats_act - actdats as av_age, year(fpedats) as year
	from 			forecast
	group by 		cusip, fpedats, analys
	having actdats = max(actdats)
	;
quit;


proc sort data = forecast1_alt nodupkey;
	by cusip fpedats analys actdats;
run;


proc sql;
	create table forecast2_alt
	as select *
	from forecast1_alt
	where av_age is not missing
	;
quit;


proc sql;
	create table age_mean_alt
	as select year, mean(av_age) as mean_age
	from forecast2_alt
	group by year
	order by year
	;
quit;




* Exercise 4;

rsubmit;

data ibes1;
	set ibes.det_epsus;
	surprise = abs(actual - value);
	if surprise = . then delete;
	if year(fpedats) = 2005;
	if fpi = '1'; 
	keep
	ticker cusip oftic actdats estimator analys value actual fpi fpedats anndats_act surprise;
run;

proc download data = ibes1 out=ibes; 
run;


endrsubmit;


proc sort data = ibes;
	by cusip fpedats analys actdats;
run; 


data forecast1; set ibes;
	by cusip fpedats analys actdats;
	if last.analys;
run;


proc sql;
	create table analy_summary
	as select analys, avg(surprise) as avg_surprise
	from forecast1
	group by analys
	order by avg_surprise
	;
quit;


proc sql;
	create table followings
	as select analys, count(cusip) as follows
	from ibes
	group by analys
	;
quit;


proc sql;
	create table 	accuana
	as select 			a.*, follows
	from 				analy_summary as a ,
							followings as b
	where 					a.analys = b.analys
	;
quit;


%WT(data=accuana, out=accuana_w, vars=avg_surprise, type = t, pctl = 1 99, drop = n);
run;

proc reg data = accuana;
	model  avg_surprise = follows;
run;




















