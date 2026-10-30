*==============================================================
* Q2 ANALYSIS DO-FILE (Stata 19.5, native twoway contour)
*
* Question 2: Is there a single indicator that tells the whole
* story, or does the interesting story only emerge when you
* look at several indicators together?
*
* Uses ONLY built-in Stata commands:
*   pwcorr, twoway contour, graph matrix, pca, screeplot,
*   estat kmo. No external packages required.
*
* Run:
*   do "C:\Users\Asus\Desktop\ASACompetition\Q2_analysis.do"
*==============================================================

clear all
set more off
set varabbrev off

*--------------------------------------------------------------
* STEP 0: Load cleaned file, or reimport + clean
*--------------------------------------------------------------
capture confirm file "C:\Users\Asus\Desktop\ASACompetition\wpp_countries.dta"

if _rc == 0 {
    use "C:\Users\Asus\Desktop\ASACompetition\wpp_countries.dta", clear
    di as result "Loaded existing wpp_countries.dta"
}
else {
    import delimited "C:\Users\Asus\Desktop\ASACompetition\WPP2024_Demographic_Indicators_Medium.csv", clear

    * Hotfix: Stata lowercases variable names on import
    rename *, lower

    * Hotfix: strip whitespace from iso3 so " " counts as missing
    replace iso3_code = strtrim(iso3_code)

    * Hotfix: is_country flag (blank ISO3 = aggregate)
    capture drop is_country
    gen byte is_country = !missing(iso3_code)

    * Hotfix: cross-check against locid < 900
    capture drop is_country2
    gen byte is_country2 = (locid < 900)
    tab is_country is_country2

    * Hotfix: keep real countries only
    keep if is_country == 1

    * Hotfix: drop 2101 and beyond
    drop if time > 2100

    di as result "Reimported and reapplied cleaning hotfixes"
}

*--------------------------------------------------------------
* STEP 1: Verify cleaning
*--------------------------------------------------------------
count
assert time <= 2100

*--------------------------------------------------------------
* STEP 2: Panel id + log transforms
*--------------------------------------------------------------
capture drop loc_id
egen loc_id = group(location)
xtset loc_id time

describe tpopulation1july popdensity

capture drop ln_pop
capture drop ln_dens
gen double ln_pop  = ln(tpopulation1july)
gen double ln_dens = ln(popdensity)

describe ln_pop ln_dens

*--------------------------------------------------------------
* STEP 3: Variable labels
*--------------------------------------------------------------
capture label variable tfr "Total fertility rate"
capture label variable lex "Life expectancy at birth"
capture label variable imr "Infant mortality rate"
capture label variable cdr "Crude death rate"
capture label variable netmigrations "Net migration (thousands)"
capture label variable popgrowthrate "Population growth rate (%)"
capture label variable medianagepop "Median age (years)"
capture label variable popsexratio "Sex ratio (males per 100 females)"
capture label variable ln_pop "Log population (July 1)"
capture label variable ln_dens "Log population density"

*--------------------------------------------------------------
* STEP 4: Pairwise correlations with significance
*--------------------------------------------------------------
local vars tfr lex imr cdr netmigrations popgrowthrate medianagepop popsexratio ln_pop ln_dens

pwcorr `vars', sig star(.05)

*--------------------------------------------------------------
* STEP 5: Correlation heatmap via twoway contour (native Stata)
*
* postfile writes (row_num, col_num, rho) for each lower-triangle
* cell; twoway contour renders the grid with a diverging palette.
* Value labels attached to row_num/col_num give named axes.
*--------------------------------------------------------------
matrix C = r(C)
local nv : word count `vars'

* --- Build long-format cell dataset with postfile ---
tempname memhold
tempfile cells
postfile `memhold' int row_num int col_num double rho using `cells'

forvalues r = 1/`nv' {
    forvalues c = 1/`nv' {
        if `r' > `c' {
            local this_rho = C[`r', `c']
            post `memhold' (`r') (`c') (`this_rho')
        }
    }
}
postclose `memhold'

preserve
use `cells', clear

* --- Attach named axis labels via value labels ---
local i = 1
foreach v of local vars {
    label define varmap `i' "`v'", add
    local i = `i' + 1
}
label values row_num varmap
label values col_num varmap

* --- Render heatmap (Stata 19.5 supports heatmap option) ---
capture graph drop heatmap
twoway contour rho col_num row_num, ///
    heatmap ///
    ccuts(-1(.2)1) ///
    ccolors(navy blue white maroon red) ///
    xlabel(1(1)`nv', valuelabel angle(45)) ///
    ylabel(1(1)`nv', valuelabel angle(0)) ///
    yscale(reverse) ///
    xtitle("") ytitle("") ///
    ztitle("Pearson r") ///
    title("Q2: Correlation heatmap (lower triangle)") ///
    subtitle("WPP2024 Medium variant, country-level, 1950-2100") ///
    note("Annotated Pearson r. Diverging red-blue scale.") ///
    name(heatmap, replace)

graph export "C:\Users\Asus\Desktop\ASACompetition\Q2_heatmap.png", width(2400) replace
restore

*--------------------------------------------------------------
* STEP 6: Curated pairs plot (native graph matrix)
*--------------------------------------------------------------
local keyvars ln_pop tfr lex netmigrations medianagepop

capture graph drop pairs
graph matrix `keyvars', half msymbol(Oh) msize(vsmall) mcolor(navy%40) jitter(2) title("Q2: Pairs plot of key indicators") subtitle("Lower triangle; off-diagonal = bivariate scatter") name(pairs, replace)

graph export "C:\Users\Asus\Desktop\ASACompetition\Q2_pairs.png", width(2400) replace

*--------------------------------------------------------------
* STEP 7: PCA + scree + KMO
*--------------------------------------------------------------
capture drop scree
pca tfr lex imr cdr netmigrations popgrowthrate medianagepop popsexratio ln_pop ln_dens, mineigen(1)

screeplot, name(scree, replace)
graph export "C:\Users\Asus\Desktop\ASACompetition\Q2_scree.png", width(2400) replace

estat kmo

*--------------------------------------------------------------
* STEP 8: Combine heatmap + pairs
*--------------------------------------------------------------
capture graph drop combined
capture graph combine heatmap pairs, rows(1) imargin(small) title("Q2: No single indicator tells the whole story") name(combined, replace)

capture graph export "C:\Users\Asus\Desktop\ASACompetition\Q2_combined.png", width(3000) replace

*--------------------------------------------------------------
* STEP 9: Save augmented .dta
*--------------------------------------------------------------
save "C:\Users\Asus\Desktop\ASACompetition\wpp_countries.dta", replace

di as result "============================================================"
di as result "Q2 analysis complete."
di as result "Outputs in C:\Users\Asus\Desktop\ASACompetition\:"
di as result "  Q2_heatmap.png, Q2_pairs.png, Q2_scree.png, Q2_combined.png"
di as result "  wpp_countries.dta (augmented)"
di as result "============================================================"