//////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main do file //////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

clear all

* Change routes if needed:
global cd "/Users/diegogonzalezgonzalez/Desktop/LOYOLA/PhD/2nd chapter"
global raw_dta "/Users/diegogonzalezgonzalez/Desktop/UC3M/TFM/MAPHABSOC/data_schools.dta"

* Optional stage argument:
*   do code/main_synth.do                -> dataprep + analysis (synth)
*   do code/main_synth.do matches        -> matching only (synth)
*   do code/main_synth.do dataprep       -> data preparation only (synth)
*   do code/main_synth.do analysis       -> analysis only (synth)
*   do code/main_synth.do all            -> matches + dataprep + analysis (synth)
args stage
if `"`stage'"'=="" local stage "run"

if inlist(`"`stage'"', "matches", "all") {
	do "$cd/code/matches_synth.do"
}

if inlist(`"`stage'"', "dataprep", "run", "all") {
	do "$cd/code/dataprep_synth.do"
}

if inlist(`"`stage'"', "analysis", "desc", "run", "all") {
	do "$cd/code/desc_synth.do"
}
