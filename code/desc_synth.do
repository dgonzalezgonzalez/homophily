//////////////////////////////////////////////////////////////////////////////
/////////////////////////// Descriptive results //////////////////////////////
//////////////////////////////////////////////////////////////////////////////

if "$cd"=="" {
	di as error "Global cd is not set. Define global cd before running desc.do."
	exit 198
}
if "$raw_dta"=="" {
	di as error "Global raw_dta is not set. Define global raw_dta before running desc.do."
	exit 198
}

capture mkdir "$cd/temp"
capture mkdir "$cd/output"

capture program drop export_png_safe
program define export_png_safe
	args outpng widthpx
	capture noisily graph export "`outpng'", width(`widthpx') replace
	if _rc {
		local outsvg = subinstr("`outpng'", ".png", ".svg", .)
		capture noisily graph export "`outsvg'", replace
		if !_rc {
			!sips -s format png "`outsvg'" --out "`outpng'" >/dev/null 2>&1
			capture erase "`outsvg'"
		}
	}
end

local need_prep = 0
capture confirm file "$cd/temp/analysis_base_synth.dta"
if _rc local need_prep = 1
foreach nwk in friend friend2 enemy2 {
	capture confirm file "$cd/temp/assort_synth_`nwk'.dta"
	if _rc local need_prep = 1
}
if `need_prep' {
	capture confirm file "$cd/temp/matches_synth_long.dta"
	if _rc {
		di as txt "Missing temp/matches_synth_long.dta; running matches_synth.do..."
		do "$cd/code/matches_synth.do"
	}
	di as txt "Building prep artifacts for desc_synth.do standalone..."
	do "$cd/code/dataprep_synth.do"
}

use "$cd/temp/analysis_base_synth.dta", clear

* Balanced sample for selected in-degree outcomes only.
local analysis_vars class_id class_size school grade group2 degree_match wdegree_match indegreef indegreebf indegreee indegreewe
egen nmiss_analysis = rowmiss(`analysis_vars')
drop if nmiss_analysis>0
drop nmiss_analysis

tempfile balanced_sample
save `balanced_sample', replace

capture mkdir "$cd/output/scatter_synth"
capture mkdir "$cd/output/distribution_synth"

//////////////////////////////////////////////////////////////////////////////
// Class-level scatter: in-degree outcomes only (friend, best friend, worst enemy)
//////////////////////////////////////////////////////////////////////////////
preserve
collapse (sum) degree_match wdegree_match indegreef indegreebf indegreee indegreewe (mean) class_size, by(class_id)
drop if degree_match==0

foreach var in degree_match wdegree_match indegreef indegreebf indegreee indegreewe {
	replace `var'=`var'/((class_size-1)*class_size)
}

foreach xvar in degree_match wdegree_match {
	quietly sum `xvar', meanonly
	local max_`xvar'=r(max)
}

foreach var in indegreef indegreebf indegreee indegreewe {
	local ylab = cond("`var'"=="indegreef","In-degree friendship", cond("`var'"=="indegreebf","In-degree best-friendship", cond("`var'"=="indegreee","In-degree enmity","In-degree worst-enmity")))
	quietly sum `var', meanonly
	local max_`var'=r(max)

	reg `var' degree_match
	local beta : display %4.2f _b[degree_match]
	local axis_max = max(`max_degree_match', `max_`var'')
	if `axis_max'<=0 local axis_max = 0.2
	local axis_step = cond(`axis_max'<=0.1, 0.02, cond(`axis_max'<=0.25, 0.05, cond(`axis_max'<=0.5, 0.1, cond(`axis_max'<=1, 0.2, 0.5))))
	local axis_max = ceil(`axis_max'/`axis_step')*`axis_step'
	local text_x = `axis_max'*0.78
	local text_y = `axis_max'*0.12
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' degree_match, mcolor(black%40)) (lfitci `var' degree_match, color(gs10%20)) (lfit `var' degree_match, color(black)), legend(off) xtitle("Matching degree") ytitle("`ylab'") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g1, replace

	reg `var' wdegree_match
	local beta : display %4.2f _b[wdegree_match]
	local axis_max = max(`max_wdegree_match', `max_`var'')
	if `axis_max'<=0 local axis_max = 0.2
	local axis_step = cond(`axis_max'<=0.1, 0.02, cond(`axis_max'<=0.25, 0.05, cond(`axis_max'<=0.5, 0.1, cond(`axis_max'<=1, 0.2, 0.5))))
	local axis_max = ceil(`axis_max'/`axis_step')*`axis_step'
	local text_x = `axis_max'*0.78
	local text_y = `axis_max'*0.12
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' wdegree_match, mcolor(black%40)) (lfitci `var' wdegree_match, color(gs10%20)) (lfit `var' wdegree_match, color(black)), legend(off) xtitle("Weighted matching degree") ytitle("`ylab'") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g2, replace

	capture graph combine g1.gph g2.gph
	export_png_safe "$cd/output/scatter_synth/scatter_`var'.png" 3600
}

capture erase g1.gph
capture erase g2.gph
restore

//////////////////////////////////////////////////////////////////////////////
// Densities: old in-degree outcome (friend&match among matched peers, dir1)
//            vs new inverse outcome (not-friend & not-match over class dyads)
//////////////////////////////////////////////////////////////////////////////

* A) Old outcomes, exactly as prior logic from assort_synth_* (dir1 mean over matches)
use `balanced_sample', clear
reshape long match_id count_match, i(usuario_id) j(n)
drop n
foreach nwk in friend friend2 enemy2 {
	merge m:1 usuario_id match_id using "$cd/temp/assort_synth_`nwk'.dta", nogen
}

foreach nwk in friend friend2 enemy2 {
	bysort usuario_id: egen p_match_`nwk' = mean(assort_`nwk'_dir1)
}

keep usuario_id p_match_friend p_match_friend2 p_match_enemy2
duplicates drop
tempfile old_in_deg_outcomes
save `old_in_deg_outcomes', replace

* B) New inverse outcomes from scratch on full class dyads
use `balanced_sample', clear
keep usuario_id class_id
duplicates drop
rename usuario_id ego_id
tempfile roster_ego roster_peer dyads match_pairs
save `roster_ego', replace

use `roster_ego', clear
rename ego_id peer_id
save `roster_peer', replace

use `roster_ego', clear
joinby class_id using `roster_peer'
drop if ego_id==peer_id
rename ego_id usuario_id
save `dyads', replace

* Match dyads: peer donor for ego (positive synth weight only)
use "$cd/temp/matches_synth_long.dta", clear
keep usuario_id match_id count_match
drop if missing(usuario_id) | missing(match_id) | missing(count_match) | count_match<=0
rename match_id peer_id
keep usuario_id peer_id
duplicates drop
gen is_match = 1
save `match_pairs', replace

* Relationship dyads (in-degree: peer -> ego)
foreach nwk in friend friend2 enemy2 {
	tempfile rel_`nwk'
	if "`nwk'"=="friend" {
		use "$cd/temp/friend.dta", clear
		keep usuario_id friend_id
		rename usuario_id peer_id
		rename friend_id usuario_id
	}
	else if "`nwk'"=="friend2" {
		use "$cd/temp/friend2.dta", clear
		keep usuario_id friend2_id
		rename usuario_id peer_id
		rename friend2_id usuario_id
	}
	else {
		use "$cd/temp/enemy2.dta", clear
		keep usuario_id enemy2_id
		rename usuario_id peer_id
		rename enemy2_id usuario_id
	}
	drop if missing(usuario_id) | missing(peer_id)
	keep usuario_id peer_id
	duplicates drop
	gen in_rel_`nwk' = 1
	save `rel_`nwk'', replace
}

use `dyads', clear
isid usuario_id peer_id
merge 1:1 usuario_id peer_id using `match_pairs', keep(master match) nogen
replace is_match = 0 if missing(is_match)

foreach nwk in friend friend2 enemy2 {
	bysort usuario_id peer_id: keep if _n==1
	merge 1:1 usuario_id peer_id using `rel_`nwk'', keep(master match) nogen
	replace in_rel_`nwk' = 0 if missing(in_rel_`nwk')
	gen notrel_notmatch_`nwk' = (in_rel_`nwk'==0 & is_match==0)
	bysort usuario_id: egen p_notrel_notmatch_`nwk' = mean(notrel_notmatch_`nwk')
}

keep usuario_id p_notrel_notmatch_friend p_notrel_notmatch_friend2 p_notrel_notmatch_enemy2
duplicates drop

isid usuario_id
merge 1:1 usuario_id using `old_in_deg_outcomes', nogen

* C) Density graphs: same file names as legacy assortativity outputs.
*    Panel 1: legacy in-degree assortativity (dir1, same trimming rule as before).
*    Panel 2: new inverse probability (not in-rel & not-match).
local friend "friendship"
local friend2 "best-friendship"
local enemy2 "worst-enmity"

foreach nwk in friend friend2 enemy2 {
	preserve
	sum p_match_`nwk', d
	if r(p75)!=0 keep if p_match_`nwk'<r(p75)
	else keep if p_match_`nwk'<r(p76)

	twoway ///
		(kdensity p_match_`nwk', lcolor(navy) lwidth(medthick) lpattern(solid)), ///
		legend(order(1 "In-``nwk'' & match (legacy)") pos(1) ring(0) cols(1) size(small)) ///
		xtitle("Assortativity") ytitle("Density")
	graph save g_old_`nwk', replace

	twoway ///
		(kdensity p_notrel_notmatch_`nwk', lcolor(cranberry) lwidth(medthick) lpattern(dash)), ///
		legend(order(1 "Not-in-``nwk'' & not-match") pos(1) ring(0) cols(1) size(small)) ///
		xtitle("Probability") ytitle("Density")
	graph save g_new_`nwk', replace

	capture graph combine g_old_`nwk'.gph g_new_`nwk'.gph, cols(2)
	export_png_safe "$cd/output/distribution_synth/dens_assort_`nwk'.png" 3400
	capture erase g_old_`nwk'.gph
	capture erase g_new_`nwk'.gph
	restore
}

* Keep compact comparison table for auditing variable construction.
keep usuario_id p_match_friend p_notrel_notmatch_friend p_match_friend2 p_notrel_notmatch_friend2 p_match_enemy2 p_notrel_notmatch_enemy2
save "$cd/temp/in_degree_match_vs_notmatch_synth.dta", replace
