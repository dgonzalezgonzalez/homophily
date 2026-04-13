//////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main do file //////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

clear all

* Change routes if needed:
global cd "/Users/diegogonzalezgonzalez/Desktop/LOYOLA/PhD/2nd chapter"
global raw_dta "/Users/diegogonzalezgonzalez/Desktop/UC3M/TFM/MAPHABSOC/data_schools.dta"

* Run do files:
*do "$cd/code/matches.do" // uncomment if you want to run the matching assignment algorithm
do "$cd/code/dataprep.do"
do "$cd/code/desc.do"
