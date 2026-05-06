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
capture confirm file "$cd/temp/assort_synth_friend.dta"
if _rc local need_prep = 1
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

* Keep balanced analysis sample: non-missing in in-degree analysis vars.
local analysis_vars class_id class_size school grade group2 degree_match wdegree_match indegreef
egen nmiss_analysis = rowmiss(`analysis_vars')
drop if nmiss_analysis>0
drop nmiss_analysis

tempfile balanced_sample
save `balanced_sample', replace

capture mkdir "$cd/output/scatter_synth"
capture mkdir "$cd/output/distribution_synth"

// Class-level in-degree correlation (only):
preserve
collapse (sum) degree_match wdegree_match indegreef (mean) class_size, by(class_id)
drop if degree_match==0

foreach var in degree_match wdegree_match indegreef {
	gen `var'_raw = `var'
}

replace degree_match = degree_match/((class_size-1)*class_size)
replace wdegree_match = wdegree_match/((class_size-1)*class_size)
replace indegreef = indegreef/((class_size-1)*class_size)

quietly sum degree_match, meanonly
local max_degree_match=r(max)
quietly sum wdegree_match, meanonly
local max_wdegree_match=r(max)
quietly sum indegreef, meanonly
local max_indegreef=r(max)

reg indegreef degree_match
local beta : display %4.2f _b[degree_match]
local axis_max = max(`max_degree_match', `max_indegreef')
if `axis_max'<=0 local axis_max = 0.2
local axis_step = cond(`axis_max'<=0.1, 0.02, cond(`axis_max'<=0.25, 0.05, cond(`axis_max'<=0.5, 0.1, cond(`axis_max'<=1, 0.2, 0.5))))
local axis_max = ceil(`axis_max'/`axis_step')*`axis_step'
local text_x = `axis_max'*0.78
local text_y = `axis_max'*0.12
twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter indegreef degree_match, mcolor(black%40)) (lfitci indegreef degree_match, color(gs10%20)) (lfit indegreef degree_match, color(black)), legend(off) xtitle("Matching degree") ytitle("In-degree friendship") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
graph save g1, replace

reg indegreef wdegree_match
local beta : display %4.2f _b[wdegree_match]
local axis_max = max(`max_wdegree_match', `max_indegreef')
if `axis_max'<=0 local axis_max = 0.2
local axis_step = cond(`axis_max'<=0.1, 0.02, cond(`axis_max'<=0.25, 0.05, cond(`axis_max'<=0.5, 0.1, cond(`axis_max'<=1, 0.2, 0.5))))
local axis_max = ceil(`axis_max'/`axis_step')*`axis_step'
local text_x = `axis_max'*0.78
local text_y = `axis_max'*0.12
twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter indegreef wdegree_match, mcolor(black%40)) (lfitci indegreef wdegree_match, color(gs10%20)) (lfit indegreef wdegree_match, color(black)), legend(off) xtitle("Weighted matching degree") ytitle("In-degree friendship") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
graph save g2, replace

capture graph combine g1.gph g2.gph
export_png_safe "$cd/output/scatter_synth/scatter_indegreef.png" 3600

capture erase g1.gph
capture erase g2.gph
restore

// Individual-level in-degree regression (only):
preserve
replace degree_match=degree_match/((class_size-1)*class_size)
replace wdegree_match=wdegree_match/((class_size-1)*class_size)
replace indegreef=indegreef/((class_size-1)*class_size)
reg indegreef degree_match, vce(cluster class_id)
reg indegreef degree_match i.school, vce(cluster class_id)
reg indegreef degree_match i.school i.grade i.group2, vce(cluster class_id)
restore

// Mechanical dyad-level construction for in-degree friend/match and non-friend/non-match.
// 1) Build balanced roster.
use `balanced_sample', clear
keep usuario_id class_id
duplicates drop
rename usuario_id ego_id
tempfile roster_ego roster_peer dyads in_friend_pairs match_pairs
save `roster_ego', replace

use `roster_ego', clear
rename ego_id peer_id
save `roster_peer', replace

use `roster_ego', clear
joinby class_id using `roster_peer'
drop if ego_id==peer_id
rename ego_id usuario_id
save `dyads', replace

// 2) In-degree friendship dyads: peer -> ego.
use "$cd/temp/friend.dta", clear
keep usuario_id friend_id
drop if missing(usuario_id) | missing(friend_id)
rename usuario_id peer_id
rename friend_id usuario_id
keep usuario_id peer_id
duplicates drop
gen in_friend = 1
save `in_friend_pairs', replace

// 3) Match dyads: peer is synthetic donor for ego.
use "$cd/temp/matches_synth_long.dta", clear
keep usuario_id match_id count_match
drop if missing(usuario_id) | missing(match_id) | missing(count_match) | count_match<=0
rename match_id peer_id
keep usuario_id peer_id
duplicates drop
gen is_match = 1
save `match_pairs', replace

// 4) Merge to full dyad universe within class.
use `dyads', clear
merge m:1 usuario_id peer_id using `in_friend_pairs', nogen
replace in_friend = 0 if missing(in_friend)
merge m:1 usuario_id peer_id using `match_pairs', nogen
replace is_match = 0 if missing(is_match)

// Mechanical dummies.
gen friend_match = (in_friend==1 & is_match==1)
gen notfriend_notmatch = (in_friend==0 & is_match==0)
gen union_friend_or_match = (in_friend==1 | is_match==1)
gen notfriend_notmatch_comp = 1 - union_friend_or_match
gen comp_gap = abs(notfriend_notmatch - notfriend_notmatch_comp)

bysort usuario_id: egen p_friend_match = mean(friend_match)
bysort usuario_id: egen p_notfriend_notmatch = mean(notfriend_notmatch)
bysort usuario_id: egen p_notfriend_notmatch_comp = mean(notfriend_notmatch_comp)
bysort usuario_id: egen max_comp_gap = max(comp_gap)

preserve
collapse (max) max_comp_gap (mean) p_friend_match p_notfriend_notmatch p_notfriend_notmatch_comp, by(usuario_id)
save "$cd/temp/notfriend_notmatch_consistency_synth.dta", replace
restore

keep usuario_id p_friend_match p_notfriend_notmatch p_notfriend_notmatch_comp max_comp_gap
duplicates drop

summ max_comp_gap, meanonly
di as txt "Max mechanical-vs-complement gap (dyad level): " %9.6f r(max)

// Density plot in same graph: assortativity (friend&match) vs inverse (notfriend&notmatch).
twoway ///
	(kdensity p_friend_match, lcolor(navy) lwidth(medthick) lpattern(solid)) ///
	(kdensity p_notfriend_notmatch, lcolor(cranberry) lwidth(medthick) lpattern(dash)), ///
	legend(order(1 "In-friend & match" 2 "Not-friend & not-match") pos(1) ring(0) cols(1) size(small)) ///
	xtitle("Probability") ytitle("Density")
export_png_safe "$cd/output/distribution_synth/dens_indegree_friend_match_vs_not.png" 3400

// Optional diagnostic overlay: mechanical vs complement version.
twoway ///
	(kdensity p_notfriend_notmatch, lcolor(forest_green) lwidth(medthick) lpattern(solid)) ///
	(kdensity p_notfriend_notmatch_comp, lcolor(black) lwidth(medthick) lpattern(shortdash)), ///
	legend(order(1 "Mechanical not-friend & not-match" 2 "Complement check") pos(1) ring(0) cols(1) size(small)) ///
	xtitle("Probability") ytitle("Density")
export_png_safe "$cd/output/distribution_synth/dens_notfriend_notmatch_check.png" 3400
