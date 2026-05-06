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
foreach nwk in friend friend2 enemy enemy2 {
	capture confirm file "$cd/temp/assort_synth_`nwk'.dta"
	if _rc local need_prep = 1
}
if `need_prep' {
	capture confirm file "$cd/temp/matches_synth_long.dta"
	if _rc {
		di as txt "Missing temp/matches.dta; running matches.do..."
		do "$cd/code/matches_synth.do"
	}
	di as txt "Building prep artifacts for desc.do standalone..."
	do "$cd/code/dataprep_synth.do"
}

use "$cd/temp/analysis_base_synth.dta", clear

* Keep a balanced analysis sample: non-missing in all variables used below.
local analysis_vars class_id class_size school grade group2 ///
	degree_match wdegree_match ///
	indegreef indegreebf indegreee indegreewe ///
	outdegreef outdegreebf outdegreee outdegreewe ///
	degreef degreebf degreee degreewe
egen nmiss_analysis = rowmiss(`analysis_vars')
drop if nmiss_analysis>0
drop nmiss_analysis

capture mkdir "$cd/output/scatter_synth"
capture mkdir "$cd/output/distribution_synth"

// Class-level degree correlations:
preserve
collapse (sum) degree_match wdegree_match indegreef indegreebf indegreee indegreewe degreef degreebf degreee degreewe outdegreef outdegreebf outdegreee outdegreewe (mean) class_size, by(class_id)
drop if degree_match==0 // these are classes with missing values
foreach var in degree_match wdegree_match indegreef indegreebf indegreee indegreewe degreef degreebf degreee degreewe outdegreef outdegreebf outdegreee outdegreewe {
	gen `var'_raw = `var'
}
* Normalize by (n-1)n term:
foreach var in degree_match wdegree_match indegreef indegreebf indegreee indegreewe outdegreef outdegreebf outdegreee outdegreewe {
	replace `var'=`var'/((class_size-1)*class_size)
}
foreach var in degreef degreebf degreee degreewe {
	replace `var'=`var'/((class_size-1)*class_size*2)
}
foreach l in in out {
	local `l'degreef "Friend"
	local `l'degreebf "Best friend"
	local `l'degreee "Enemy"
	local `l'degreewe "Worst enemy"
}
local degreef "Friend"
local degreebf "Best friend"
local degreee "Enemy"
local degreewe "Worst enemy"
foreach xvar in degree_match wdegree_match {
	quietly sum `xvar', meanonly
	local max_`xvar'=r(max)
}
foreach var in indegreef indegreebf indegreee indegreewe degreef degreebf degreee degreewe outdegreef outdegreebf outdegreee outdegreewe {
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
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' degree_match, mcolor(black%40)) (lfitci `var' degree_match, color(gs10%20)) (lfit `var' degree_match, color(black)), legend(off) xtitle("Matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g1, replace
	reg `var' wdegree_match
	local beta : display %4.2f _b[wdegree_match]
	local axis_max = max(`max_wdegree_match', `max_`var'')
	if `axis_max'<=0 local axis_max = 0.2
	local axis_step = cond(`axis_max'<=0.1, 0.02, cond(`axis_max'<=0.25, 0.05, cond(`axis_max'<=0.5, 0.1, cond(`axis_max'<=1, 0.2, 0.5))))
	local axis_max = ceil(`axis_max'/`axis_step')*`axis_step'
	local text_x = `axis_max'*0.78
	local text_y = `axis_max'*0.12
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' wdegree_match, mcolor(black%40)) (lfitci `var' wdegree_match, color(gs10%20)) (lfit `var' wdegree_match, color(black)), legend(off) xtitle("Weighted matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g2, replace
	capture graph combine g1.gph g2.gph
	export_png_safe "$cd/output/scatter_synth/scatter_`var'.png" 3600
}
capture erase g1.gph
capture erase g2.gph

* Alternative normalization: denominator is classroom ties by network family.
foreach var in degree_match wdegree_match indegreef indegreebf indegreee indegreewe degreef degreebf degreee degreewe outdegreef outdegreebf outdegreee outdegreewe {
	replace `var'=`var'_raw
}
gen denom_in_fe = indegreef_raw + indegreee_raw
gen denom_out_fe = outdegreef_raw + outdegreee_raw
gen denom_deg_fe = degreef_raw + degreee_raw
gen denom_in_bw = indegreebf_raw + indegreewe_raw
gen denom_out_bw = outdegreebf_raw + outdegreewe_raw
gen denom_deg_bw = degreebf_raw + degreewe_raw

foreach var in indegreef indegreee {
	replace `var'=`var'/denom_in_fe
}
foreach var in outdegreef outdegreee {
	replace `var'=`var'/denom_out_fe
}
foreach var in degreef degreee {
	replace `var'=`var'/(2*denom_deg_fe)
}
foreach var in indegreebf indegreewe {
	replace `var'=`var'/denom_in_bw
}
foreach var in outdegreebf outdegreewe {
	replace `var'=`var'/denom_out_bw
}
foreach var in degreebf degreewe {
	replace `var'=`var'/(2*denom_deg_bw)
}

foreach var in indegreef indegreee {
	replace degree_match=degree_match_raw/denom_in_fe
	replace wdegree_match=wdegree_match_raw/denom_in_fe
	quietly sum degree_match, meanonly
	local max_degree_match=r(max)
	quietly sum wdegree_match, meanonly
	local max_wdegree_match=r(max)
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
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' degree_match, mcolor(black%40)) (lfitci `var' degree_match, color(gs10%20)) (lfit `var' degree_match, color(black)), legend(off) xtitle("Matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g1, replace
	reg `var' wdegree_match
	local beta : display %4.2f _b[wdegree_match]
	local axis_max = max(`max_wdegree_match', `max_`var'')
	if `axis_max'<=0 local axis_max = 0.2
	local axis_step = cond(`axis_max'<=0.1, 0.02, cond(`axis_max'<=0.25, 0.05, cond(`axis_max'<=0.5, 0.1, cond(`axis_max'<=1, 0.2, 0.5))))
	local axis_max = ceil(`axis_max'/`axis_step')*`axis_step'
	local text_x = `axis_max'*0.78
	local text_y = `axis_max'*0.12
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' wdegree_match, mcolor(black%40)) (lfitci `var' wdegree_match, color(gs10%20)) (lfit `var' wdegree_match, color(black)), legend(off) xtitle("Weighted matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g2, replace
	capture graph combine g1.gph g2.gph
	export_png_safe "$cd/output/scatter_synth/scatter_altnorm_`var'.png" 3600
}

foreach var in outdegreef outdegreee {
	replace degree_match=degree_match_raw/denom_out_fe
	replace wdegree_match=wdegree_match_raw/denom_out_fe
	quietly sum degree_match, meanonly
	local max_degree_match=r(max)
	quietly sum wdegree_match, meanonly
	local max_wdegree_match=r(max)
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
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' degree_match, mcolor(black%40)) (lfitci `var' degree_match, color(gs10%20)) (lfit `var' degree_match, color(black)), legend(off) xtitle("Matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g1, replace
	reg `var' wdegree_match
	local beta : display %4.2f _b[wdegree_match]
	local axis_max = max(`max_wdegree_match', `max_`var'')
	if `axis_max'<=0 local axis_max = 0.2
	local axis_step = cond(`axis_max'<=0.1, 0.02, cond(`axis_max'<=0.25, 0.05, cond(`axis_max'<=0.5, 0.1, cond(`axis_max'<=1, 0.2, 0.5))))
	local axis_max = ceil(`axis_max'/`axis_step')*`axis_step'
	local text_x = `axis_max'*0.78
	local text_y = `axis_max'*0.12
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' wdegree_match, mcolor(black%40)) (lfitci `var' wdegree_match, color(gs10%20)) (lfit `var' wdegree_match, color(black)), legend(off) xtitle("Weighted matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g2, replace
	capture graph combine g1.gph g2.gph
	export_png_safe "$cd/output/scatter_synth/scatter_altnorm_`var'.png" 3600
}

foreach var in indegreebf indegreewe {
	replace degree_match=degree_match_raw/denom_in_bw
	replace wdegree_match=wdegree_match_raw/denom_in_bw
	quietly sum degree_match, meanonly
	local max_degree_match=r(max)
	quietly sum wdegree_match, meanonly
	local max_wdegree_match=r(max)
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
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' degree_match, mcolor(black%40)) (lfitci `var' degree_match, color(gs10%20)) (lfit `var' degree_match, color(black)), legend(off) xtitle("Matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g1, replace
	reg `var' wdegree_match
	local beta : display %4.2f _b[wdegree_match]
	local axis_max = max(`max_wdegree_match', `max_`var'')
	if `axis_max'<=0 local axis_max = 0.2
	local axis_step = cond(`axis_max'<=0.1, 0.02, cond(`axis_max'<=0.25, 0.05, cond(`axis_max'<=0.5, 0.1, cond(`axis_max'<=1, 0.2, 0.5))))
	local axis_max = ceil(`axis_max'/`axis_step')*`axis_step'
	local text_x = `axis_max'*0.78
	local text_y = `axis_max'*0.12
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' wdegree_match, mcolor(black%40)) (lfitci `var' wdegree_match, color(gs10%20)) (lfit `var' wdegree_match, color(black)), legend(off) xtitle("Weighted matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g2, replace
	capture graph combine g1.gph g2.gph
	export_png_safe "$cd/output/scatter_synth/scatter_altnorm_`var'.png" 3600
}

foreach var in outdegreebf outdegreewe {
	replace degree_match=degree_match_raw/denom_out_bw
	replace wdegree_match=wdegree_match_raw/denom_out_bw
	quietly sum degree_match, meanonly
	local max_degree_match=r(max)
	quietly sum wdegree_match, meanonly
	local max_wdegree_match=r(max)
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
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' degree_match, mcolor(black%40)) (lfitci `var' degree_match, color(gs10%20)) (lfit `var' degree_match, color(black)), legend(off) xtitle("Matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g1, replace
	reg `var' wdegree_match
	local beta : display %4.2f _b[wdegree_match]
	local axis_max = max(`max_wdegree_match', `max_`var'')
	if `axis_max'<=0 local axis_max = 0.2
	local axis_step = cond(`axis_max'<=0.1, 0.02, cond(`axis_max'<=0.25, 0.05, cond(`axis_max'<=0.5, 0.1, cond(`axis_max'<=1, 0.2, 0.5))))
	local axis_max = ceil(`axis_max'/`axis_step')*`axis_step'
	local text_x = `axis_max'*0.78
	local text_y = `axis_max'*0.12
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' wdegree_match, mcolor(black%40)) (lfitci `var' wdegree_match, color(gs10%20)) (lfit `var' wdegree_match, color(black)), legend(off) xtitle("Weighted matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g2, replace
	capture graph combine g1.gph g2.gph
	export_png_safe "$cd/output/scatter_synth/scatter_altnorm_`var'.png" 3600
}

foreach var in degreef degreee {
	replace degree_match=degree_match_raw/(2*denom_deg_fe)
	replace wdegree_match=wdegree_match_raw/(2*denom_deg_fe)
	quietly sum degree_match, meanonly
	local max_degree_match=r(max)
	quietly sum wdegree_match, meanonly
	local max_wdegree_match=r(max)
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
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' degree_match, mcolor(black%40)) (lfitci `var' degree_match, color(gs10%20)) (lfit `var' degree_match, color(black)), legend(off) xtitle("Matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g1, replace
	reg `var' wdegree_match
	local beta : display %4.2f _b[wdegree_match]
	local axis_max = max(`max_wdegree_match', `max_`var'')
	if `axis_max'<=0 local axis_max = 0.2
	local axis_step = cond(`axis_max'<=0.1, 0.02, cond(`axis_max'<=0.25, 0.05, cond(`axis_max'<=0.5, 0.1, cond(`axis_max'<=1, 0.2, 0.5))))
	local axis_max = ceil(`axis_max'/`axis_step')*`axis_step'
	local text_x = `axis_max'*0.78
	local text_y = `axis_max'*0.12
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' wdegree_match, mcolor(black%40)) (lfitci `var' wdegree_match, color(gs10%20)) (lfit `var' wdegree_match, color(black)), legend(off) xtitle("Weighted matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g2, replace
	capture graph combine g1.gph g2.gph
	export_png_safe "$cd/output/scatter_synth/scatter_altnorm_`var'.png" 3600
}

foreach var in degreebf degreewe {
	replace degree_match=degree_match_raw/(2*denom_deg_bw)
	replace wdegree_match=wdegree_match_raw/(2*denom_deg_bw)
	quietly sum degree_match, meanonly
	local max_degree_match=r(max)
	quietly sum wdegree_match, meanonly
	local max_wdegree_match=r(max)
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
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' degree_match, mcolor(black%40)) (lfitci `var' degree_match, color(gs10%20)) (lfit `var' degree_match, color(black)), legend(off) xtitle("Matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g1, replace
	reg `var' wdegree_match
	local beta : display %4.2f _b[wdegree_match]
	local axis_max = max(`max_wdegree_match', `max_`var'')
	if `axis_max'<=0 local axis_max = 0.2
	local axis_step = cond(`axis_max'<=0.1, 0.02, cond(`axis_max'<=0.25, 0.05, cond(`axis_max'<=0.5, 0.1, cond(`axis_max'<=1, 0.2, 0.5))))
	local axis_max = ceil(`axis_max'/`axis_step')*`axis_step'
	local text_x = `axis_max'*0.78
	local text_y = `axis_max'*0.12
	twoway (function y=x, range(0 `axis_max') lcolor(gs8) lpattern(shortdash)) (scatter `var' wdegree_match, mcolor(black%40)) (lfitci `var' wdegree_match, color(gs10%20)) (lfit `var' wdegree_match, color(black)), legend(off) xtitle("Weighted matching degree") ytitle("``var'' degree") xscale(range(0 `axis_max')) yscale(range(0 `axis_max')) xlabel(0(`axis_step')`axis_max') ylabel(0(`axis_step')`axis_max') text(`text_y' `text_x' "β = `beta'")
	graph save g2, replace
	capture graph combine g1.gph g2.gph
	export_png_safe "$cd/output/scatter_synth/scatter_altnorm_`var'.png" 3600
}

drop *_raw denom_in_fe denom_out_fe denom_deg_fe denom_in_bw denom_out_bw denom_deg_bw
capture erase g1.gph
capture erase g2.gph
restore

// Individual-level degree correlations:
preserve
* Normalize by (n-1)n term:
foreach var in degree_match wdegree_match indegreef indegreebf indegreee indegreewe {
	replace `var'=`var'/((class_size-1)*class_size)
}
reg indegreef degree_match, vce(cluster class_id)
reg indegreef degree_match i.school, vce(cluster class_id)
reg indegreef degree_match i.school i.grade i.group2, vce(cluster class_id)
restore

// Assortativity at the micro-level:
reshape long match_id count_match, i(usuario_id) j(n)
drop n
foreach nwk in friend friend2 enemy enemy2 {
	merge m:1 usuario_id match_id using "$cd/temp/assort_synth_`nwk'.dta", nogen
}
foreach nwk in friend friend2 enemy enemy2 {
	foreach var in dir1 dir2 union inter {
		bysort usuario_id: egen assort_`nwk'_`var'_avg = mean(assort_`nwk'_`var')
		bysort usuario_id: egen _w_num = total(assort_`nwk'_`var' * count_match)
		bysort usuario_id: egen _w_den = total(count_match)
		gen wassort_`nwk'_`var'_avg = _w_num / _w_den if _w_den>0
		drop _w_num _w_den
		drop assort_`nwk'_`var' wassort_`nwk'_`var'
		rename (assort_`nwk'_`var'_avg wassort_`nwk'_`var'_avg) (assort_`nwk'_`var' wassort_`nwk'_`var')
	}
}

drop match_id count_match
duplicates drop

* Build inverse assortativity probability on full class dyads:
* P(not in-relation AND not matched), by ego.
tempfile assort_base inv_probs roster_ego roster_peer dyads match_pairs
save `assort_base', replace

preserve
keep usuario_id class_id
duplicates drop
rename usuario_id ego_id
save `roster_ego', replace

use `roster_ego', clear
rename ego_id peer_id
save `roster_peer', replace

use `roster_ego', clear
joinby class_id using `roster_peer'
drop if ego_id==peer_id
rename ego_id usuario_id
save `dyads', replace

use "$cd/temp/matches_synth_long.dta", clear
keep usuario_id match_id count_match
drop if missing(usuario_id) | missing(match_id) | missing(count_match) | count_match<=0
rename match_id peer_id
keep usuario_id peer_id
duplicates drop
gen is_match = 1
save `match_pairs', replace

use `dyads', clear
merge m:1 usuario_id peer_id using `match_pairs', keep(master match) nogen
replace is_match = 0 if missing(is_match)

foreach nwk in friend friend2 enemy enemy2 {
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
	else if "`nwk'"=="enemy" {
		use "$cd/temp/enemy.dta", clear
		keep usuario_id enemy_id
		rename usuario_id peer_id
		rename enemy_id usuario_id
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
merge m:1 usuario_id peer_id using `match_pairs', keep(master match) nogen
replace is_match = 0 if missing(is_match)

foreach nwk in friend friend2 enemy enemy2 {
	merge m:1 usuario_id peer_id using `rel_`nwk'', keep(master match) nogen
	replace in_rel_`nwk' = 0 if missing(in_rel_`nwk')
	gen notrel_notmatch_`nwk' = (in_rel_`nwk'==0 & is_match==0)
	bysort usuario_id: egen p_notrel_notmatch_`nwk' = mean(notrel_notmatch_`nwk')
}

keep usuario_id p_notrel_notmatch_friend p_notrel_notmatch_friend2 p_notrel_notmatch_enemy p_notrel_notmatch_enemy2
duplicates drop
save `inv_probs', replace
restore

use `assort_base', clear
merge m:1 usuario_id using `inv_probs', keep(master match) nogen

local friend "friendship"
local friend2 "best-friendship"
local enemy "enemity"
local enemy2 "worst-enemity"
foreach nwk in friend friend2 enemy enemy2 {
	preserve
	sum assort_`nwk'_dir1, d
	if r(p75)!=0 keep if assort_`nwk'_dir1<r(p75)
	else keep if assort_`nwk'_dir1<r(p76)
	twoway (kdensity assort_`nwk'_dir1, lcolor(navy) lwidth(medthick) lpattern(solid)) (kdensity p_notrel_notmatch_`nwk', lcolor(cranberry) lwidth(medthick) lpattern(dash)), legend(order(1 "In-``nwk'' & match" 2 "Not-in-``nwk'' & not-match") pos(1) ring(0) cols(1) size(small)) xtitle("Assortativity") ytitle("Density")
	graph save g`nwk', replace
	export_png_safe "$cd/output/distribution_synth/dens_assort_`nwk'.png" 3200
	twoway (kdensity wassort_`nwk'_dir1, lcolor(navy) lwidth(medthick) lpattern(solid)) (kdensity p_notrel_notmatch_`nwk', lcolor(cranberry) lwidth(medthick) lpattern(dash)), legend(order(1 "Weighted in-``nwk'' & match" 2 "Not-in-``nwk'' & not-match") pos(1) ring(0) cols(1) size(small)) xtitle("Assortativity") ytitle("Density")
	graph save wg`nwk', replace
	export_png_safe "$cd/output/distribution_synth/dens_wassort_`nwk'.png" 3200
	restore
}
capture graph combine gfriend.gph gfriend2.gph genemy.gph genemy2.gph
export_png_safe "$cd/output/distribution_synth/dens_assort.png" 3400
capture graph combine wgfriend.gph wgfriend2.gph wgenemy.gph wgenemy2.gph
export_png_safe "$cd/output/distribution_synth/dens_wassort.png" 3400
foreach g in gfriend gfriend2 genemy genemy2 {
	capture erase `g'.gph
	capture erase w`g'.gph
}
