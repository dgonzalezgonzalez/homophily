//////////////////////////////////////////////////////////////////////////////
////////////////////////// Equivalence validation ////////////////////////////
//////////////////////////////////////////////////////////////////////////////

args baseline_dir
if `"`baseline_dir'"'=="" local baseline_dir "/tmp/homophily_baseline/temp"

capture confirm file "`baseline_dir'/analysis_base_old.dta"
if _rc {
	di as error "Baseline file not found: `baseline_dir'/analysis_base_old.dta"
	exit 601
}

local baseline_files friend friend2 enemy enemy2 assort_friend assort_friend2 assort_enemy assort_enemy2
foreach stub in `baseline_files' {
	capture confirm file "`baseline_dir'/`stub'.dta"
	if _rc {
		di as error "Baseline file not found: `baseline_dir'/`stub'.dta"
		exit 601
	}
	capture confirm file "$cd/temp/`stub'.dta"
	if _rc {
		di as error "Current file not found: $cd/temp/`stub'.dta"
		exit 601
	}
}

foreach fig in scatter_degreebf scatter_degreee scatter_degreef scatter_degreewe scatter_indegreebf scatter_indegreee scatter_indegreef scatter_indegreewe scatter_outdegreebf scatter_outdegreee scatter_outdegreef scatter_outdegreewe {
	capture confirm file "$cd/output/scatter/`fig'.png"
	if _rc {
		di as error "Expected output missing: $cd/output/scatter/`fig'.png"
		exit 601
	}
}

foreach fig in dens_assort dens_assort_enemy dens_assort_enemy2 dens_assort_friend dens_assort_friend2 dens_wassort dens_wassort_enemy dens_wassort_enemy2 dens_wassort_friend dens_wassort_friend2 {
	capture confirm file "$cd/output/distribution/`fig'.png"
	if _rc {
		di as error "Expected output missing: $cd/output/distribution/`fig'.png"
		exit 601
	}
}

foreach stub in friend friend2 enemy enemy2 assort_friend assort_friend2 assort_enemy assort_enemy2 {
	use "$cd/temp/`stub'.dta", clear
	unab sortvars : _all
	sort `sortvars'
	tempfile current_sorted
	save `current_sorted', replace

	use "`baseline_dir'/`stub'.dta", clear
	unab sortvars : _all
	sort `sortvars'
	tempfile baseline_sorted
	save `baseline_sorted', replace

	use `current_sorted', clear
	capture noisily cf _all using `baseline_sorted', all
	if _rc {
		di as error "Dataset mismatch: `stub'.dta"
		exit _rc
	}
}

use "$cd/temp/analysis_base.dta", clear
unab sortvars : _all
sort `sortvars'
tempfile current_analysis
save `current_analysis', replace

use "`baseline_dir'/analysis_base_old.dta", clear
unab sortvars : _all
sort `sortvars'
tempfile baseline_analysis
save `baseline_analysis', replace

use `current_analysis', clear
capture noisily cf _all using `baseline_analysis', all
if _rc {
	di as error "Dataset mismatch: analysis_base.dta"
	exit _rc
}

di as txt "Equivalence validation passed."
