//////////////////////////////////////////////////////////////////////////////
/////////////////////////// Descriptive results //////////////////////////////
//////////////////////////////////////////////////////////////////////////////

capture confirm file "$cd/temp/analysis_base.dta"
if _rc {
	di as error "Required file not found: $cd/temp/analysis_base.dta"
	exit 601
}

use "$cd/temp/analysis_base.dta", clear

// Class-level degree correlations:
preserve
collapse (sum) degree_match wdegree_match indegreef indegreebf indegreee indegreewe degreef degreebf degreee degreewe outdegreef outdegreebf outdegreee outdegreewe (mean) class_size, by(class_id)
drop if degree_match==0 // these are classes with missing values
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
	graph combine g1.gph g2.gph
	graph export "$cd/output/scatter_`var'.png", replace
}
erase g1.gph
erase g2.gph
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
	merge m:1 usuario_id match_id using "$cd/temp/assort_`nwk'.dta", nogen
}
foreach nwk in friend friend2 enemy enemy2 {
	foreach var in dir1 dir2 union inter {
		bysort usuario_id: egen assort_`nwk'_`var'_avg=mean(assort_`nwk'_`var')
		bysort usuario_id: egen wassort_`nwk'_`var'_avg=mean(wassort_`nwk'_`var')
		drop assort_`nwk'_`var' wassort_`nwk'_`var'
		rename (assort_`nwk'_`var'_avg wassort_`nwk'_`var'_avg) (assort_`nwk'_`var' wassort_`nwk'_`var')
	}
}

drop match_id count_match
duplicates drop

local friend "friendship"
local friend2 "best-friendship"
local enemy "enemity"
local enemy2 "worst-enemity"
foreach nwk in friend friend2 enemy enemy2 {
	preserve
	sum assort_`nwk'_dir1, d
	if r(p75)!=0 keep if assort_`nwk'_dir1<r(p75)
	else keep if assort_`nwk'_dir1<r(p76)
	twoway (kdensity assort_`nwk'_dir1, lcolor(navy) lwidth(medthick) lpattern(solid)) (kdensity assort_`nwk'_dir2, lcolor(cranberry) lwidth(medthick) lpattern(dash)) (kdensity assort_`nwk'_union, lcolor(forest_green) lwidth(medthick) lpattern(dot)) (kdensity assort_`nwk'_inter, lcolor(dkorange) lwidth(medthick) lpattern(longdash)), legend(order(1 "Out-``nwk''" 2 "In-``nwk''" 3 "Union" 4 "Intersection") pos(1) ring(0) cols(1) size(small)) xtitle("Assortativity") ytitle("Density")
	graph save g`nwk', replace
	graph export "$cd/output/dens_assort_`nwk'.png", replace
	twoway (kdensity wassort_`nwk'_dir1, lcolor(navy) lwidth(medthick) lpattern(solid)) (kdensity wassort_`nwk'_dir2, lcolor(cranberry) lwidth(medthick) lpattern(dash)) (kdensity wassort_`nwk'_union, lcolor(forest_green) lwidth(medthick) lpattern(dot)) (kdensity wassort_`nwk'_inter, lcolor(dkorange) lwidth(medthick) lpattern(longdash)), legend(order(1 "Out-``nwk''" 2 "In-``nwk''" 3 "Union" 4 "Intersection") pos(1) ring(0) cols(1) size(small)) xtitle("Weighted assortativity") ytitle("Density")
	graph save wg`nwk', replace
	graph export "$cd/output/dens_wassort_`nwk'.png", replace
	restore
}
graph combine gfriend.gph gfriend2.gph genemy.gph genemy2.gph
graph export "$cd/output/dens_assort.png", replace
graph combine wgfriend.gph wgfriend2.gph wgenemy.gph wgenemy2.gph
graph export "$cd/output/dens_wassort.png", replace
foreach g in gfriend gfriend2 genemy genemy2 {
	erase `g'.gph
	erase w`g'.gph
}
