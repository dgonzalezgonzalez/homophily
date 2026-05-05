//////////////////////////////////////////////////////////////////////////////
//////////////// Synthetic-control style twin assignment /////////////////////
//////////////////////////////////////////////////////////////////////////////

capture mkdir "$cd/temp"

use $raw_dta, clear
keep if country==1

global xlist gender scoreN migrant bullying_union moodgeneral patienceN crtN finN riskyN inequalityN honest

* Keep complete cases on matching covariates (balanced covariate matrix).
egen miss_x = rowmiss($xlist)
drop if miss_x>0
drop miss_x

* Build duplicated panel as requested: te=1/2.
preserve
gen te = 1
tempfile copy1 copy2
save `copy1', replace
replace te = 2
save `copy2', replace
use `copy1', clear
append using `copy2'
save "$cd/temp/synth_panel_base.dta", replace
restore

tempfile base class_raw class_t class_d class_edges all_edges
save `base', replace
quietly levelsof class_id, local(class_list)
clear
save `all_edges', emptyok replace

foreach c in `class_list' {
	use `base', clear
	keep if class_id=="`c'"
	quietly count
	if r(N)<2 continue
	save `class_raw', replace

	use `class_raw', clear
	keep usuario_id class_id $xlist
	foreach x of global xlist {
		rename `x' t_`x'
	}
	save `class_t', replace

	use `class_raw', clear
	keep usuario_id class_id $xlist
	rename usuario_id match_id
	foreach x of global xlist {
		rename `x' d_`x'
	}
	save `class_d', replace

	use `class_t', clear
	joinby class_id using `class_d'
	drop if usuario_id==match_id

	gen dist_sq = 0
	foreach x of global xlist {
		replace dist_sq = dist_sq + (t_`x' - d_`x')^2
	}

	gsort usuario_id dist_sq
	by usuario_id: gen donor_rank = _n
	keep if donor_rank<=10
	drop donor_rank

	gen inv_dist = 1/(dist_sq + 1e-8)
	by usuario_id: egen inv_sum = total(inv_dist)
	gen count_match = inv_dist/inv_sum

	keep usuario_id match_id count_match
	append using `all_edges'
	save `all_edges', replace
}

use `all_edges', clear
drop if missing(usuario_id) | missing(match_id) | missing(count_match)
sort usuario_id match_id
save "$cd/temp/matches_synth_long.dta", replace

bysort usuario_id (count_match): gen match_n = _N - _n + 1
reshape wide match_id count_match, i(usuario_id) j(match_n)
save "$cd/temp/matches_synth.dta", replace
