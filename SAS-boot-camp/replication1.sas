%let wrds=wrds-cloud.wharton.upenn.edu 4016;
options comamid=TCP remote = WRDS;
signon user = _prompt_;


libname rep1 'C:\Users\zynda\Documents\Fall-2018\SAS-boot-camp';

rsubmit;

data comp; set comp.funda (where = (indfmt = 'INDL' and datafmt = 'STD' and popsrc = 'D'
							and consol = 'C')
							keep = gvkey cusip cik tic conm sich fyr fyear datadate exchg sale dlc dltt dd1
							prcc_f csho mkvalt at ib indfmt datafmt popsrc consol);
	if year(datadate) ge 1999;
	if year(datadate) le 2001;
	if gvkey ne .;
	if at gt 0;
run;


proc download data = comp;
quit;

endrsubmit;


data comp; 
	set comp;
	if fyr le 5 then calendar_year = fyear+1; else calendar_year = fyear;
	nmo = ((year(datadate)-1960)*12)+fyr);
	cusip9 = substr(cusip,1,8);
	length Ticker $6.; Ticker = tic;
	lag_at = lag(at);
	lag_sale = lag(sale);
	lag_gvkey = lag(gvket);
	lag_fyear = lag(fyear);

	if gvkey != lag_gvkey or lag_fyear+1 != fyear then lag_sale=.;
	if gvkey ne lag_gvkey or lag_fyear+1 ne fyear then lag_at =.;
	salesgrowth = (sale - lag_sale) / lag_sale;
	ROA = ib / ((at + lag_sale) / lag_sale)
