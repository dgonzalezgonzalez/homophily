//////////////////////////////////////////////////////////////////////////////
///////////////////// Matching assignment algorithm //////////////////////////
//////////////////////////////////////////////////////////////////////////////

use $raw_dta, clear
keep if country==1
preserve
keep usuario_id
tempfile temp
save "`temp'"
restore
global xlist gender scoreN migrant bullying_union moodgeneral patienceN crtN finN riskyN inequalityN honest

* Bootstrap the whole process

local nboots=100 // number of reps

qui forvalues m=1(1)`nboots' {
	use $raw_dta, clear
	keep if country==1
	levelsof class_id, local(class)
	foreach n in `class' {
		preserve
		keep if class_id=="`n'"
		* Randomly assign individuals within each class:
		set seed 12345`m'
		sort usuario_id
		gen treat=runiform()<0.5
		* Nearest-neighbor matching:
		capture qui teffects nnmatch (usuario_id $xlist) (treat), gen(flag) nn(1)
		if _rc!=0 {
			restore
			continue
		}
		keep usuario_id class_id flag1
		
		gen row_n = _n
		* Create a lookup: store usuario_id indexed by row number
		* Use a temporary dataset approach with frames (Stata 16+)
		frame copy default lookup, replace
		frame change lookup
		keep usuario_id row_n
		frame change default
		frlink m:1 flag1, frame(lookup row_n)
		frget match`m' = usuario_id, from(lookup)
		drop lookup row_n
		merge 1:1 usuario_id using "`temp'", nogen
		save "`temp'", replace
		restore
	}
}
merge 1:1 usuario_id using "`temp'", nogen
keep usuario_id match*
save "$cd/temp/matches.dta", replace
