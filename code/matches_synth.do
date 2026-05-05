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
tempfile copy1 copy2 panel_base
save `copy1', replace
replace te = 2
save `copy2', replace
use `copy1', clear
append using `copy2'
save "$cd/temp/synth_panel_base.dta", replace
restore

tempfile class_input class_edges all_edges
save `class_input', replace
clear
save `all_edges', emptyok replace

levelsof class_id, local(class_list)

foreach c in `class_list' {
	use `class_input', clear
	keep if class_id=="`c'"
	quietly count
	if r(N)<2 continue

	mata:
		X = st_data(., tokens(st_global("xlist")))
		ids = st_data(., "usuario_id")
		n = rows(X)
		k = cols(X)
		edges = J(0,3,.)

		for (i=1; i<=n; i++) {
			keep = selectindex((1::n):!=i)
			Xd = X[keep,.]'
			xt = X[i,.]'
			m = rows(keep)
			if (m<1) continue
			w = J(m,1,1/m)
			step = 0.05

			for (it=1; it<=1200; it++) {
				g = 2 :* (Xd' * (Xd*w - xt))
				w = w - step :* g
				w = w :* (w:>=0)
				s = sum(w)
				if (s<=1e-12) w = J(m,1,1/m)
				else w = w/s
			}

			for (j=1; j<=m; j++) {
				if (w[j]>1e-8) {
					edges = edges \ (ids[i], ids[keep[j]], w[j])
				}
			}
		}

		st_addvar("double", ("usuario_id","match_id","count_match"))
		st_addobs(rows(edges))
		if (rows(edges)>0) {
			st_store((1::rows(edges)), ("usuario_id","match_id","count_match"), edges)
		}
	end

	keep usuario_id match_id count_match
	tempfile class_edges
	save `class_edges', replace
	use `all_edges', clear
	append using `class_edges'
	save `all_edges', replace
}

use `all_edges', clear
drop if missing(usuario_id) | missing(match_id) | missing(count_match)
sort usuario_id match_id
save "$cd/temp/matches_synth_long.dta", replace

* Wide copy (for easy inspection, analogous to old matches.dta).
bysort usuario_id (count_match): gen match_n = _N - _n + 1
reshape wide match_id count_match, i(usuario_id) j(match_n)
save "$cd/temp/matches_synth.dta", replace
