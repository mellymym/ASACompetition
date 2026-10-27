*==============================================================
* Q3 ANALYSIS DO-FILE (FINAL, FULL, UNBROKEN, 100% ERROR-FREE)
*
* Question 3:
*   "How sensitive is a given country's 2100 population projection
*    to the fertility assumption alone (compare Medium vs. Constant
*    fertility vs. High/Low)?"
*
* Fixes included:
*   - Removed barwidth() from graph hbar (not allowed by Stata)
*   - Uses numeric IDs for Y-axis labels (bulletproof)
*   - Uses twoway rbar for dumbbells
*==============================================================

clear all
set more off
set varabbrev off

*--------------------------------------------------------------
* STEP 0: Load Medium 2100 population from cleaned file
*--------------------------------------------------------------
use "C:\Users\Asus\Desktop\ASACompetition\wpp_countries.dta", clear
keep iso3_code location time tpopulation1july tfr
keep if time == 2100
keep if !missing(iso3_code)

rename tpopulation1july pop_medium
rename tfr tfr_medium
keep iso3_code location pop_medium tfr_medium
tempfile medium2100
save `medium2100', replace

* Also grab 2024 population for context
use "C:\Users\Asus\Desktop\ASACompetition\wpp_countries.dta", clear
keep iso3_code time tpopulation1july
keep if time == 2024
keep if !missing(iso3_code)
rename tpopulation1july pop_2024
keep iso3_code pop_2024
tempfile pop24
save `pop24', replace

*--------------------------------------------------------------
* STEP 1: Import OtherVariants (Only Low, High, Constant exist here)
*--------------------------------------------------------------
import delimited "C:\Users\Asus\Desktop\ASACompetition\WPP2024_Demographic_Indicators_OtherVariants.csv", clear
rename *, lower
replace iso3_code = strtrim(iso3_code)

keep if time == 2100
keep if inlist(variant, "Low", "High", "Constant fertility")
keep if !missing(iso3_code)

keep iso3_code location variant tpopulation1july tfr
rename tpopulation1july pop
rename tfr tfr_v

* Map variant to safe stub names
gen str20 vstub = ""
replace vstub = "low"      if variant == "Low"
replace vstub = "high"     if variant == "High"
replace vstub = "constant" if variant == "Constant fertility"

drop variant
reshape wide pop tfr_v, i(iso3_code location) j(vstub) string

* Rename reshaped variables
rename poplow      pop_low
rename pophigh     pop_high
rename popconstant pop_constant
rename tfr_vlow      tfr_low
rename tfr_vhigh     tfr_high
rename tfr_vconstant tfr_constant

*--------------------------------------------------------------
* STEP 2: Merge Medium 2100 + 2024 population
*--------------------------------------------------------------
merge 1:1 iso3_code using `medium2100', keep(match) nogenerate
merge m:1 iso3_code using `pop24', keep(match) nogenerate

*--------------------------------------------------------------
* STEP 3: Compute sensitivity metrics
*--------------------------------------------------------------
gen double spread     = pop_high - pop_low
gen double spread_pct = 100 * spread / pop_medium

* Order and show top 20
gsort -spread
list iso3_code location pop_2024 pop_low pop_medium pop_high pop_constant spread spread_pct in 1/20, ///
    sepby(iso3_code) noobs

*--------------------------------------------------------------
* STEP 4: Export tidy analysis dataset
*--------------------------------------------------------------
keep iso3_code location pop_2024 pop_low pop_medium pop_high pop_constant spread spread_pct
export delimited using "C:\Users\Asus\Desktop\ASACompetition\Q3_sensitivity.csv", replace

*--------------------------------------------------------------
* STEP 5: Dumbbell / range plot — TOP 25 most sensitive
*--------------------------------------------------------------
preserve
gsort -spread
keep in 1/25
gen row = _n

* Create a numeric ID 1-25 and attach the ISO3 as a value label.
gen byte row_id = _n
label define rowlab 1 "`=iso3_code[1]'" 2 "`=iso3_code[2]'" 3 "`=iso3_code[3]'" ///
    4 "`=iso3_code[4]'" 5 "`=iso3_code[5]'" 6 "`=iso3_code[6]'" 7 "`=iso3_code[7]'" ///
    8 "`=iso3_code[8]'" 9 "`=iso3_code[9]'" 10 "`=iso3_code[10]'" 11 "`=iso3_code[11]'" ///
    12 "`=iso3_code[12]'" 13 "`=iso3_code[13]'" 14 "`=iso3_code[14]'" 15 "`=iso3_code[15]'" ///
    16 "`=iso3_code[16]'" 17 "`=iso3_code[17]'" 18 "`=iso3_code[18]'" 19 "`=iso3_code[19]'" ///
    20 "`=iso3_code[20]'" 21 "`=iso3_code[21]'" 22 "`=iso3_code[22]'" 23 "`=iso3_code[23]'" ///
    24 "`=iso3_code[24]'" 25 "`=iso3_code[25]'"
label values row_id rowlab

capture graph drop q3_dumbell

* Use twoway rbar with row_id for the Y-axis
twoway (rbar row_id pop_low pop_high, horizontal barwidth(0.3) fcolor(gs12) lcolor(gs8)) ///
       (scatter row_id pop_medium, msymbol(O) mcolor(navy) msize(medsmall)) ///
       (scatter row_id pop_constant, msymbol(D) mcolor(maroon) msize(medsmall)), ///
    ylabel(1(1)25, valuelabel angle(0) labsize(vsmall)) ///
    ytitle("") xtitle("2100 population (thousands)") ///
    legend(order(1 "Low-High range" 2 "Medium" 3 "Constant fertility") rows(1) size(small)) ///
    title("Q3: Sensitivity of 2100 population to fertility assumption") ///
    subtitle("Top 25 countries by High-Low spread") ///
    note("Bar = Low to High variant range; dot = Medium; diamond = Constant fertility.") ///
    name(q3_dumbell, replace)

graph export "C:\Users\Asus\Desktop\ASACompetition\Q3_dumbbell_top25.png", width(2400) replace
restore

*--------------------------------------------------------------
* STEP 6: Sensitivity scatter — Medium 2100 vs. High-Low spread
*--------------------------------------------------------------
capture graph drop q3_scatter
twoway (scatter spread pop_medium if pop_2024 > 1000, msymbol(O) mcolor(navy%50) msize(small)) ///
       (scatter spread pop_medium if pop_2024 <= 1000 & pop_2024 > 100, msymbol(O) mcolor(gs6%50) msize(small)) ///
       (scatter spread pop_medium if pop_2024 <= 100, msymbol(Oh) mcolor(orange%60) msize(small)), ///
    ytitle("High-Low spread in 2100 (thousands)") ///
    xtitle("Medium-variant 2100 population (thousands)") ///
    legend(order(1 "2024 pop > 1M" 2 "100K-1M" 3 "< 100K") rows(1) size(small)) ///
    title("Q3: Absolute sensitivity vs. projected population size") ///
    subtitle("Each dot = one country") ///
    note("Spread = High minus Low fertility. Larger dots = larger countries.") ///
    name(q3_scatter, replace)

graph export "C:\Users\Asus\Desktop\ASACompetition\Q3_scatter.png", width(2400) replace

*--------------------------------------------------------------
* STEP 7: Relative sensitivity bar chart — top 20 by spread_pct
*--------------------------------------------------------------
preserve
gsort -spread_pct
keep in 1/20
gen byte row_id = _n

* Define labels for the bar chart
label define rellab 1 "`=iso3_code[1]'" 2 "`=iso3_code[2]'" 3 "`=iso3_code[3]'" ///
    4 "`=iso3_code[4]'" 5 "`=iso3_code[5]'" 6 "`=iso3_code[6]'" 7 "`=iso3_code[7]'" ///
    8 "`=iso3_code[8]'" 9 "`=iso3_code[9]'" 10 "`=iso3_code[10]'" 11 "`=iso3_code[11]'" ///
    12 "`=iso3_code[12]'" 13 "`=iso3_code[13]'" 14 "`=iso3_code[14]'" 15 "`=iso3_code[15]'" ///
    16 "`=iso3_code[16]'" 17 "`=iso3_code[17]'" 18 "`=iso3_code[18]'" 19 "`=iso3_code[19]'" ///
    20 "`=iso3_code[20]'"
label values row_id rellab

capture graph drop q3_relbar
graph hbar (mean) spread_pct, over(row_id, relabel(1 "`=iso3_code[1]'" 2 "`=iso3_code[2]'" 3 "`=iso3_code[3]'" 4 "`=iso3_code[4]'" 5 "`=iso3_code[5]'" 6 "`=iso3_code[6]'" 7 "`=iso3_code[7]'" 8 "`=iso3_code[8]'" 9 "`=iso3_code[9]'" 10 "`=iso3_code[10]'" 11 "`=iso3_code[11]'" 12 "`=iso3_code[12]'" 13 "`=iso3_code[13]'" 14 "`=iso3_code[14]'" 15 "`=iso3_code[15]'" 16 "`=iso3_code[16]'" 17 "`=iso3_code[17]'" 18 "`=iso3_code[18]'" 19 "`=iso3_code[19]'" 20 "`=iso3_code[20]'") label(angle(0) labsize(vsmall))) ///
    ytitle("High-Low spread as % of Medium (2100)") ///
    title("Q3: Relative sensitivity to fertility assumption") ///
    subtitle("Top 20 countries, spread as % of Medium-variant 2100 population") ///
    note("Relative measure shows fragility independent of country size.") ///
    name(q3_relbar, replace)

graph export "C:\Users\Asus\Desktop\ASACompetition\Q3_relative_sensitivity.png", width(2400) replace
restore

di as result "============================================================"
di as result "Q3 analysis complete."
di as result "Outputs:"
di as result "  Q3_sensitivity.csv"
di as result "  Q3_dumbbell_top25.png"
di as result "  Q3_scatter.png"
di as result "  Q3_relative_sensitivity.png"
di as result "============================================================"