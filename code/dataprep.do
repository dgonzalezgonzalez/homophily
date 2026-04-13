//////////////////////////////////////////////////////////////////////////////
///////////////////////////// Data preparation ///////////////////////////////
//////////////////////////////////////////////////////////////////////////////

// Friendship data prep:

foreach nwk in friend friend2 enemy enemy2 {
	use $raw_dta, clear
	keep if country==1
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

use $raw_dta, clear
keep if country==1
merge 1:1 usuario_id using "$cd/temp/matches.dta", nogen

* Reshape to long format:
reshape long match, i(usuario_id) j(match_n)
rename match match_id

* Generate match network metrics:
bysort usuario_id (match_id): gen degree_match = sum(match_id != match_id[_n-1])
bysort usuario_id: replace degree_match = degree_match[_N]
replace degree_match=. if degree_match==0

bysort usuario_id match_id: gen count_match = _N
replace count_match=. if degree_match==.

sum match_n
gen freq=count_match/r(max)
bysort usuario_id: egen wdegree_match=sum(freq^2)
replace wdegree_match=1/wdegree_match
drop freq

* Reshape back to wide format:
reshape wide match_id count_match, i(usuario_id) j(match_n)

// Assorativity data prep:

cd "$cd/temp"

foreach nwk in friend friend2 enemy enemy2 {
	preserve
	keep usuario_id match_id* count_match*
	reshape long match_id count_match, i(usuario_id) j(n)
	drop n
	duplicates drop
	save assort_`nwk'.dta, replace
	restore

	/* ══════════════════════════════════════════════════════════════════════════
	   (1)  `nwk': usuario_id → match_id
			Has usuario_id declared match_id as a `nwk'?
			Lookup (usuario_id, match_id) in `nwk'.dta as (usuario_id, `nwk'_id)
	   ══════════════════════════════════════════════════════════════════════════ */

	preserve
	use `nwk'.dta, clear
	keep usuario_id `nwk'_id
	rename `nwk'_id match_id
	gen assort_`nwk'_dir1 = 1
	duplicates drop
	save _temp_dir1.dta, replace
	restore

	* We merge m:1 over (usuario_id, match_id)
	preserve
	use assort_`nwk'.dta, clear
	merge m:1 usuario_id match_id using _temp_dir1.dta, keep(master match) nogen

	* If it exists, assort_`nwk'_dir1 = 1; otherwise, = 0
	replace assort_`nwk'_dir1 = 0 if missing(assort_`nwk'_dir1)
	save assort_`nwk'.dta, replace
	restore

	/* ══════════════════════════════════════════════════════════════════════════
	   (2)  inverse `nwk' : match_id → usuario_id
			Has match_id declared usuario_id as `nwk'?
			Lookup (match_id, usuario_id) in `nwk'.dta as (usuario_id, `nwk'_id)
	   ══════════════════════════════════════════════════════════════════════════ */

	preserve
	use `nwk'.dta, clear
	keep usuario_id `nwk'_id
	rename usuario_id match_id
	rename `nwk'_id usuario_id
	gen assort_`nwk'_dir2 = 1
	duplicates drop
	save _temp_dir2.dta, replace
	restore

	preserve
	use assort_`nwk'.dta, clear
	merge m:1 usuario_id match_id using _temp_dir2.dta, keep(master match) nogen

	replace assort_`nwk'_dir2 = 0 if missing(assort_`nwk'_dir2)

	/* ══════════════════════════════════════════════════════════════════════════
	   (3)  Union: at least one declared the other is a `nwk'
	   ══════════════════════════════════════════════════════════════════════════ */

	gen assort_`nwk'_union = (assort_`nwk'_dir1 == 1 | assort_`nwk'_dir2 == 1)

	/* ══════════════════════════════════════════════════════════════════════════
	   (4)  Intersection: both mutually declared `nwk'ship
	   ══════════════════════════════════════════════════════════════════════════ */

	gen assort_`nwk'_inter = (assort_`nwk'_dir1 == 1 & assort_`nwk'_dir2 == 1)

	sum count_match
	foreach var in assort_`nwk'_dir1 assort_`nwk'_dir2 assort_`nwk'_union assort_`nwk'_inter {
		replace `var'=. if match_id==.
		gen w`var'=`var'*(count_match/r(max))
	}

	erase _temp_dir1.dta
	erase _temp_dir2.dta
	save assort_`nwk'.dta, replace
	restore
}
