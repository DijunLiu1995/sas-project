proc sql;
	create table sample1
	as select a.*, b.lpermno as permno
	from ????? as a left join crsp.CCMXPF_LNKHISY
		(where=(LINKTYPE in ('LC', 'LU') and linkprim in ('P', 'C'))) as b 
	on a.gvkey = b.gvket and ((b.linkdt <= a.datadate) or (b.linkdt = .B)) and ((a.datadate <= b.linkenddt) or (b.linkenddt = .E));

quit;

proc sort data = comp_link nodupkey;
	by gvket fyear;
quit;

rsubmit;


