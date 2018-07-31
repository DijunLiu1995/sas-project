* Example 4;

%let wrds=wrds-cloud.wharton.upenn.edu 4016;
options comamid=TCP remote = WRDS;
signon user = _prompt_;

rsubmit;
data compsample;
	set comp.anncomp
		(keep = cusip coname ticker exec_fullname year salary
			bonus stock_awards option_awards age title);
	if year EQ 2006; 
run;

proc download data = compsample;
run;

endrsubmit;
signoff;

data compsample; 
	set compsample;
	cash_comp = salary + bonus;
	equity_comp = stock_awards + option_awards;
	total_comp = cash_comp + equity_comp;

proc sort data = compsample; 
	by descending total_comp;

proc print data = compsample (obs=10);
	var ticker cash_comp equity_comp total_comp exec_fullname;
run;
