//////////////////////////////////////////////////////////////////////////////
///////////////////////// Data preparation (synth) ///////////////////////////
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

// Synth matches data prep:
use "$cd/temp/matches_synth_long.dta", clear
sort usuario_id match_id

* Synthetic-control donor weights are stored in count_match.
gen synth_weight = count_match
drop if missing(synth_weight) | synth_weight<=0

bysort usuario_id (match_id): gen degree_match = sum(match_id != match_id[_n-1])
bysort usuario_id: replace degree_match = degree_match[_N]
replace degree_match=. if degree_match==0

* Weighted tie mass per ego (recommended for size-oriented normalization).
bysort usuario_id: egen wdegree_match = total(synth_weight)

save `match_long', replace

drop synth_weight
bysort usuario_id (count_match): gen match_n = _N - _n + 1
reshape wide match_id count_match, i(usuario_id) j(match_n)
save "$cd/temp/analysis_base_synth.dta", replace

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
	keep usuario_id match_id count_match synth_weight
	duplicates drop
	merge m:1 usuario_id match_id using `dir1', keep(master match) nogen
	replace assort_`nwk'_dir1 = 0 if missing(assort_`nwk'_dir1)
	merge m:1 usuario_id match_id using `dir2', keep(master match) nogen
	replace assort_`nwk'_dir2 = 0 if missing(assort_`nwk'_dir2)

	gen assort_`nwk'_union = (assort_`nwk'_dir1 == 1 | assort_`nwk'_dir2 == 1)
	gen assort_`nwk'_inter = (assort_`nwk'_dir1 == 1 & assort_`nwk'_dir2 == 1)

	foreach var in assort_`nwk'_dir1 assort_`nwk'_dir2 assort_`nwk'_union assort_`nwk'_inter {
		replace `var'=. if match_id==.
		gen w`var'=`var'*synth_weight
	}
	save "$cd/temp/assort_synth_`nwk'.dta", replace
}

use "$cd/temp/analysis_base_synth.dta", clear
merge 1:1 usuario_id using `base_sample', nogen keep(match)
save "$cd/temp/analysis_base_synth.dta", replace
