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

tempfile base keep_w
save `base', replace
levelsof class_id, local(class_list)

tempname donorh vh
postfile `donorh' double usuario_id double match_id double count_match using "$cd/temp/matches_synth_long.dta", replace
postfile `vh' double usuario_id str32 covariate double v_weight using "$cd/temp/matches_synth_vweights.dta", replace

foreach c in `class_list' {
	use `base', clear
	keep if class_id=="`c'"
	quietly count
	if r(N)<2 continue

	levelsof usuario_id, local(treated_ids)

	foreach tu of local treated_ids {
		use `base', clear
		keep if class_id=="`c'"
		expand 2
		bys usuario_id: gen te = _n
		xtset usuario_id te

		capture erase `keep_w'
		capture quietly synth scoreN gender scoreN migrant bullying_union moodgeneral patienceN crtN finN riskyN inequalityN honest, ///
			trunit(`tu') trperiod(2) keep(`keep_w') replace
		if _rc!=0 continue

		* Store donor weights for treated unit.
		use `keep_w', clear
		keep _Co_Number _W_Weight
		rename _Co_Number match_id
		rename _W_Weight count_match
		drop if missing(count_match)
		quietly count
		if r(N)>0 {
			forvalues i = 1/`=_N' {
				post `donorh' (`tu') (match_id[`i']) (count_match[`i'])
			}
		}

		* Store covariate weights (diagonal of V matrix).
		matrix V = e(V_matrix)
		local p = rowsof(V)
		local j = 0
		foreach vname of global xlist {
			local ++j
			if `j'>`p' continue, break
			scalar wj = V[`j',`j']
			post `vh' (`tu') ("`vname'") (wj)
		}
	}
}

postclose `donorh'
postclose `vh'

use "$cd/temp/matches_synth_long.dta", clear
drop if missing(usuario_id) | missing(match_id) | missing(count_match) | count_match<=0
sort usuario_id match_id
save "$cd/temp/matches_synth_long.dta", replace

bysort usuario_id (count_match): gen match_n = _N - _n + 1
reshape wide match_id count_match, i(usuario_id) j(match_n)
save "$cd/temp/matches_synth.dta", replace
