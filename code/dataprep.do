//////////////////////////////////////////////////////////////////////////////
///////////////////////////// Data preparation ///////////////////////////////
//////////////////////////////////////////////////////////////////////////////

tempfile base_sample match_long dir1 dir2

use $raw_dta, clear
keep if country==1
save `base_sample', replace

// Friendship data prep:
foreach nwk in friend friend2 enemy enemy2 {
	use `base_sample', clear
	keep usuario_id `nwk'
	split `nwk', parse("|") gen(`nwk')
	foreach var in `r(varlist)' {
		destring `var', replace
	}
	drop `nwk'
	reshape long `nwk', i(usuario_id) j(`nwk'_n)
	drop if `nwk'==.
	rename (`nwk' `nwk'_n) (`nwk'_id `nwk')
	save "$cd/temp/`nwk'.dta", replace
}

// Matches data prep:
use `base_sample', clear
merge 1:1 usuario_id using "$cd/temp/matches.dta", nogen

* Reshape to long format:
reshape long match, i(usuario_id) j(match_n)
rename match match_id
sort usuario_id match_id

* Generate match network metrics:
bysort usuario_id (match_id): gen degree_match = sum(match_id != match_id[_n-1])
bysort usuario_id: replace degree_match = degree_match[_N]
replace degree_match=. if degree_match==0

bysort usuario_id match_id: gen count_match = _N
replace count_match=. if degree_match==.

quietly sum match_n, meanonly
gen freq=count_match/r(max)
bysort usuario_id: egen wdegree_match=total(freq^2)
replace wdegree_match=100*(1/wdegree_match)
drop freq
save `match_long', replace

* Reshape back to wide format for analysis:
reshape wide match_id count_match, i(usuario_id) j(match_n)
save "$cd/temp/analysis_base.dta", replace

// Assortativity data prep:
foreach nwk in friend friend2 enemy enemy2 {
	use "$cd/temp/`nwk'.dta", clear
	keep usuario_id `nwk'_id
	rename `nwk'_id match_id
	gen assort_`nwk'_dir1 = 1
	duplicates drop
	save `dir1', replace

	use "$cd/temp/`nwk'.dta", clear
	keep usuario_id `nwk'_id
	rename usuario_id match_id
	rename `nwk'_id usuario_id
	gen assort_`nwk'_dir2 = 1
	duplicates drop
	save `dir2', replace

	use `match_long', clear
	keep usuario_id match_id count_match
	duplicates drop
	merge m:1 usuario_id match_id using `dir1', keep(master match) nogen
	replace assort_`nwk'_dir1 = 0 if missing(assort_`nwk'_dir1)
	merge m:1 usuario_id match_id using `dir2', keep(master match) nogen
	replace assort_`nwk'_dir2 = 0 if missing(assort_`nwk'_dir2)

	gen assort_`nwk'_union = (assort_`nwk'_dir1 == 1 | assort_`nwk'_dir2 == 1)
	gen assort_`nwk'_inter = (assort_`nwk'_dir1 == 1 & assort_`nwk'_dir2 == 1)

	quietly sum count_match, meanonly
	local max_count = r(max)
	foreach var in assort_`nwk'_dir1 assort_`nwk'_dir2 assort_`nwk'_union assort_`nwk'_inter {
		replace `var'=. if match_id==.
		gen w`var'=`var'*(count_match/`max_count')
	}
	save "$cd/temp/assort_`nwk'.dta", replace
}

use "$cd/temp/analysis_base.dta", clear
