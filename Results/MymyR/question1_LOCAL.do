*==============================================================
* Q1 ANALYSIS DO-FILE (FINAL, FULL, UNBROKEN)
*
* Question 1:
*   "How do fertility, mortality, and migration act together to
*    shape a country's overall population trajectory — and does
*    that relationship differ across regions or income levels?"
*
* Fixes included:
*   - Numeric reg_id used for graph names (prevents r198 invalid name)
*   - Compound double quotes `"..."' used for titles (prevents r132 too few quotes)
*   - No nested levelsof string extraction
*   - Region merge via ParentID with string-prefix fallback
*   - CNMR excluded from indexed plots (near-zero base explodes)
*==============================================================

clear all
set more off
set varabbrev off

*--------------------------------------------------------------
* STEP 0: Load cleaned country file
*--------------------------------------------------------------
use "C:\Users\Asus\Desktop\ASACompetition\wpp_countries.dta", clear

keep location iso3_code parentid time tpopulation1july tfr cdr cnmr

*--------------------------------------------------------------
* STEP 1: Build region map from raw CSV aggregate rows
*--------------------------------------------------------------
preserve
import delimited "C:\Users\Asus\Desktop\ASACompetition\WPP2024_Demographic_Indicators_Medium.csv", clear
rename *, lower
replace iso3_code = strtrim(iso3_code)

keep if missing(iso3_code)
keep locid location loctypename
duplicates drop locid location loctypename, force
keep if inlist(loctypename, "Region", "Subregion", "Intermediate Region", "Geographic region", "Group")

rename location region_label
rename locid parentid
tempfile regions
save `regions', replace
restore

*--------------------------------------------------------------
* STEP 2: Merge region label onto countries via ParentID
*--------------------------------------------------------------
capture confirm numeric variable parentid
if _rc != 0 {
    destring parentid, replace ignore(" ")
}

merge m:1 parentid using `regions', keep(master match) nogenerate

qui levelsof region_label if !missing(region_label), local(reglist)
local nreg : word count `reglist'
di as result "Regions after ParentID merge: `nreg'"

*--------------------------------------------------------------
* STEP 2b: Fallback if ParentID merge failed
*--------------------------------------------------------------
if `nreg' < 3 {
    di as result "ParentID merge weak — applying string-prefix fallback."
    capture drop region_label
    gen str30 region_label = ""
    replace region_label = "Africa"            if strpos(location, "Africa") > 0
    replace region_label = "Asia"              if strpos(location, "Asia") > 0 & region_label == ""
    replace region_label = "Europe"            if strpos(location, "Europe") > 0 & region_label == ""
    replace region_label = "Latin America"     if strpos(location, "America") > 0 & region_label == "" & strpos(location, "Northern") == 0
    replace region_label = "Northern America"  if inlist(iso3_code,"USA","CAN","BMU","GRL","SPM")
    replace region_label = "Oceania"           if strpos(location, "Oceania") > 0 & region_label == ""
    replace region_label = "Other" if region_label == ""
}

qui levelsof region_label if region_label != "" & !missing(region_label), local(reglist)
local nreg : word count `reglist'
di as result "Final distinct regions used in plots: `nreg'"
if `nreg' < 3 {
    di as error "Only `nreg' regions — aborting."
    exit 459
}
tab region_label

*--------------------------------------------------------------
* STEP 3: Restrict window, collapse to region-year
*--------------------------------------------------------------
keep if inrange(time, 1950, 2100)
keep if !missing(tfr) & !missing(cdr) & !missing(cnmr) & !missing(tpopulation1july)
keep if region_label != ""

collapse (mean) tfr cdr cnmr tpopulation1july, by(region_label time)

*--------------------------------------------------------------
* STEP 4: Indexed trajectories
*--------------------------------------------------------------
encode region_label, gen(reg_id)

bysort reg_id (time): gen byte base = (_n == 1)
bysort reg_id: egen double base_pop = min(cond(base==1, tpopulation1july, .))
bysort reg_id: egen double base_tfr = min(cond(base==1, tfr, .))
bysort reg_id: egen double base_cdr = min(cond(base==1, cdr, .))

gen double pop_idx = 100 * tpopulation1july / base_pop
gen double tfr_idx = 100 * tfr            / base_tfr
gen double cdr_idx = 100 * cdr            / base_cdr

drop if missing(pop_idx)

*--------------------------------------------------------------
* STEP 5: Driver trajectories grid (safe title extraction)
*--------------------------------------------------------------
qui levelsof reg_id, local(reg_ids)
local graphs ""

foreach id of local reg_ids {
    * Safely extract the label without levelsof quoting issues
    local r_lab ""
    qui forvalues k = 1/`=_N' {
        if region_label[`k'] != "" & reg_id[`k'] == `id' {
            local r_lab = region_label[`k']
            continue, break
        }
    }
    * Strip characters that break title parsing
    local r_lab = subinstr("`r_lab'", `"""', "", .)
    local r_lab = subinstr("`r_lab'", "'", "", .)
    local r_lab = subinstr("`r_lab'", "`", "", .)

    twoway (line pop_idx time if reg_id==`id', lcolor(navy) lwidth(medthick)) ///
           (line tfr_idx time if reg_id==`id', lcolor(maroon) lpattern(solid)) ///
           (line cdr_idx time if reg_id==`id', lcolor(forest_green) lpattern(dash)), ///
        title(`"`r_lab'"', size(small)) ///
        ytitle("") xtitle("") ///
        yline(100, lcolor(gs10) lpattern(dot)) ///
        yscale(range(0 250)) ///
        legend(off) ///
        name(g`id', replace) nodraw

    local graphs "`graphs' g`id'"
}

graph combine `graphs', ///
    cols(3) xcommon ycommon imargin(2) ///
    title("Q1: Driver trajectories by region (indexed, 1950 = 100)") ///
    subtitle("TFR, CDR, and Population") ///
    note("") ///
    name(q1_panel, replace)

graph export "C:\Users\Asus\Desktop\ASACompetition\Q1_panel_indexed.png", width(2400) replace

*--------------------------------------------------------------
* STEP 6: Population-only log scale grid
*--------------------------------------------------------------
local graphs2 ""

foreach id of local reg_ids {
    local r_lab ""
    qui forvalues k = 1/`=_N' {
        if region_label[`k'] != "" & reg_id[`k'] == `id' {
            local r_lab = region_label[`k']
            continue, break
        }
    }
    local r_lab = subinstr("`r_lab'", `"""', "", .)
    local r_lab = subinstr("`r_lab'", "'", "", .)
    local r_lab = subinstr("`r_lab'", "`", "", .)

    twoway (line tpopulation1july time if reg_id==`id', lcolor(navy) lwidth(medthick)), ///
        title(`"`r_lab'"', size(small)) ///
        ytitle("") xtitle("") ///
        yscale(log) ///
        legend(off) ///
        name(p`id', replace) nodraw

    local graphs2 "`graphs2' p`id'"
}

graph combine `graphs2', ///
    cols(3) xcommon ycommon imargin(2) ///
    title("Q1: Population trajectories by region") ///
    subtitle("Log scale (thousands)") ///
    note("") ///
    name(q1_pop, replace)

graph export "C:\Users\Asus\Desktop\ASACompetition\Q1_pop_by_region.png", width(2400) replace

*--------------------------------------------------------------
* STEP 7: Income tiers
*--------------------------------------------------------------
preserve
use "C:\Users\Asus\Desktop\ASACompetition\wpp_countries.dta", clear
keep if time == 2023
keep location lex tpopulation1july
xtile income_proxy = lex, nq(4)
label define inc 1 "Q1 (lowest LEx)" 2 "Q2" 3 "Q3" 4 "Q4 (highest LEx)"
label values income_proxy inc
keep location income_proxy
tempfile inc
save `inc', replace
restore

use "C:\Users\Asus\Desktop\ASACompetition\wpp_countries.dta", clear
merge m:1 location using `inc', keep(master match) nogenerate
keep if !missing(income_proxy)

keep if inrange(time, 1950, 2100)
keep if !missing(tfr) & !missing(cdr) & !missing(cnmr) & !missing(tpopulation1july)

collapse (mean) tfr cdr cnmr tpopulation1july, by(income_proxy time)

bysort income_proxy (time): gen byte base = (_n == 1)
bysort income_proxy: egen double base_pop = min(cond(base==1, tpopulation1july, .))
bysort income_proxy: egen double base_tfr = min(cond(base==1, tfr, .))
bysort income_proxy: egen double base_cdr = min(cond(base==1, cdr, .))

gen double pop_idx = 100 * tpopulation1july / base_pop
gen double tfr_idx = 100 * tfr            / base_tfr
gen double cdr_idx = 100 * cdr            / base_cdr

*--------------------------------------------------------------
* STEP 8: Income-tier grid
*--------------------------------------------------------------
local graphs3 ""
forvalues i = 1/4 {
    twoway (line pop_idx time if income_proxy==`i', lcolor(navy) lwidth(medthick)) ///
           (line tfr_idx time if income_proxy==`i', lcolor(maroon) lpattern(solid)) ///
           (line cdr_idx time if income_proxy==`i', lcolor(forest_green) lpattern(dash)), ///
        title("Q`i'", size(small)) ///
        ytitle("") xtitle("") ///
        yline(100, lcolor(gs10) lpattern(dot)) ///
        yscale(range(0 250)) ///
        legend(off) ///
        name(inc_`i', replace) nodraw

    local graphs3 "`graphs3' inc_`i'"
}

graph combine `graphs3', ///
    rows(2) cols(2) xcommon ycommon imargin(2) ///
    title("Q1: Driver trajectories by income proxy (LEx quartile, 2023)") ///
    subtitle("TFR, CDR, and Population") ///
    note("") ///
    name(q1_income, replace)

graph export "C:\Users\Asus\Desktop\ASACompetition\Q1_panel_income.png", width(2400) replace

di as result "============================================================"
di as result "Q1 analysis complete."
di as result "Outputs: Q1_panel_indexed.png, Q1_pop_by_region.png, Q1_panel_income.png"
di as result "============================================================"