//////////////////////////////////////////////////////////////////////////////
//////////////////// Synth covariate-weight descriptive //////////////////////
//////////////////////////////////////////////////////////////////////////////

if "$cd"=="" {
	di as error "Global cd is not set. Define global cd before running weights_synth.do."
	exit 198
}

capture mkdir "$cd/output"
capture mkdir "$cd/output/weights_synth"

capture confirm file "$cd/temp/matches_synth_vweights.dta"
if _rc {
	di as error "Missing temp/matches_synth_vweights.dta. Run code/matches_synth.do first."
	exit 601
}

use "$cd/temp/matches_synth_vweights.dta", clear
drop if missing(covariate) | missing(v_weight)

collapse (count) n=v_weight (mean) mean_v=v_weight (p50) med_v=v_weight (p25) p25_v=v_weight (p75) p75_v=v_weight, by(covariate)
gsort -mean_v covariate

gen covariate_label = covariate
replace covariate_label = "Gender" if covariate=="gender"
replace covariate_label = "Score" if covariate=="scoreN"
replace covariate_label = "Migrant" if covariate=="migrant"
replace covariate_label = "Bullying" if covariate=="bullying_union"
replace covariate_label = "Mood" if covariate=="moodgeneral"
replace covariate_label = "Patience" if covariate=="patienceN"
replace covariate_label = "CRT" if covariate=="crtN"
replace covariate_label = "Financial literacy" if covariate=="finN"
replace covariate_label = "Risk tolerance" if covariate=="riskyN"
replace covariate_label = "Inequality attitudes" if covariate=="inequalityN"
replace covariate_label = "Honesty" if covariate=="honest"

order covariate covariate_label n mean_v med_v p25_v p75_v
export delimited using "$cd/output/weights_synth/synth_covariate_vweights_summary.csv", replace

tempfile wsum
save `wsum', replace

file open tex using "$cd/output/weights_synth/synth_covariate_vweights_table.tex", write replace
file write tex "\begin{table}[!htbp]" _n
file write tex "\centering" _n
file write tex "\caption{Synthetic-control covariate weights (V-matrix diagonal)}" _n
file write tex "\begin{tabular}{lccccc}" _n
file write tex "\hline" _n
file write tex "Covariate & Mean & Median & P25 & P75 & N \\\\" _n
file write tex "\hline" _n

use `wsum', clear
quietly count
forvalues i=1/`=r(N)' {
	local cov = covariate_label[`i']
	local mean : display %9.4f mean_v[`i']
	local med  : display %9.4f med_v[`i']
	local p25  : display %9.4f p25_v[`i']
	local p75  : display %9.4f p75_v[`i']
	local nn   : display %9.0f n[`i']
	file write tex "`cov' & `mean' & `med' & `p25' & `p75' & `nn' \\\\" _n
}

file write tex "\hline" _n
file write tex "\end{tabular}" _n
file write tex "\end{table}" _n
file close tex

graph hbar mean_v, over(covariate_label, sort(mean_v) descending label(labsize(small))) ///
	ytitle("Average V weight") title("Synthetic-control covariate importance")
graph export "$cd/output/weights_synth/synth_covariate_vweights_mean.png", width(3200) replace

