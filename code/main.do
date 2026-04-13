//////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main do file //////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

clear all

* Change routes if needed:
global cd "/Users/diegogonzalezgonzalez/Desktop/LOYOLA/PhD/2nd chapter"
global raw_dta "/Users/diegogonzalezgonzalez/Desktop/UC3M/TFM/MAPHABSOC/data_schools.dta"

* Optional stage argument:
*   do code/main.do                -> dataprep + analysis
*   do code/main.do matches        -> matching only
*   do code/main.do dataprep       -> data preparation only
*   do code/main.do analysis       -> analysis only
*   do code/main.do all            -> matches + dataprep + analysis
args stage
if `"`stage'"'=="" local stage "run"

if inlist(`"`stage'"', "matches", "all") {
	do "$cd/code/matches.do"
}

if inlist(`"`stage'"', "dataprep", "run", "all") {
	do "$cd/code/dataprep.do"
}

if inlist(`"`stage'"', "analysis", "desc", "run", "all") {
	do "$cd/code/desc.do"
}
