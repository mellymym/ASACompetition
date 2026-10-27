*==============================================================================
* ASA DataQuest 2026 - UN World Population Prospects 2024 (Medium variant)
* One do-file: cleaning + validation + all graphs (Q1, Q4, Q5, Q6, Q7, Q8)
*
* HOW TO RUN
*   1. Unzip WPP2024_Demographic_Indicators_Medium_csv.gz (7-Zip) and rename the
*      extracted file so it ends in .csv
*   2. Edit ONLY section 0 (folder + file name + number of clusters)
*   3. Run the whole file (do ASA_codigo_final.do). Each section is independent
*      after section 1 has created the .dta files, so you can rerun any section.
*
* Requires Stata 15+ (UTF-8 accents in graph text). No user-written packages.
* Graph text is in Spanish; translate the title()/note() strings if needed.
*==============================================================================
version 16
clear all
set more off
set seed 12345

*------------------------------------------------------------------------------
* 0. SETTINGS (edit only this block)
*------------------------------------------------------------------------------
global dir  "C:\Users\Asus\Desktop\ASACompetition"                                           // working folder
global csv  "$dir/WPP2024_Demographic_Indicators_Medium.csv"   // unzipped CSV
global out  "$dir/resultados"                                  // outputs folder
global K    3                                                  // number of clusters (see section 6)

capture mkdir "$out"
capture log close
log using "$out/log_analisis.smcl", replace

* Colour-blind-safe palette (Okabe-Ito). c1..c6 = regions, gp1..gp6 = cluster groups
global c1 "213 94 0"      // Africa
global c2 "0 114 178"     // Asia
global c3 "0 158 115"     // Europe
global c4 "230 159 0"     // Latin America and the Caribbean
global c5 "204 121 167"   // Northern America
global c6 "86 180 233"    // Oceania
global gp1 "0 114 178"
global gp2 "230 159 0"
global gp3 "0 158 115"
global gp4 "204 121 167"
global gp5 "86 180 233"
global gp6 "213 94 0"

global fuente "Fuente: ONU, World Population Prospects 2024 (variante media). Línea punteada: inicio de proyecciones (2024)."

* Small helper: export the graph in memory as a high-resolution PNG
capture program drop gexp
program define gexp
    args nombre
    graph export "$out/`nombre'.png", width(2400) replace
end

*------------------------------------------------------------------------------
* 1. IMPORT, CLEAN AND VALIDATE
*    Goal: never mix countries with regional / income aggregates (double counting)
*------------------------------------------------------------------------------
import delimited using "$csv", clear varnames(1) encoding("utf-8")

* Safety: make sure the indicator columns are numeric
foreach v of varlist tpopulation1jan-cnmr {
    capture confirm numeric variable `v'
    if _rc destring `v', replace force
}

* 2101 is empty for every indicator in the file -> drop it
drop if time > 2100

* Value labels: regions (1-6) and income groups (11-14)
label define lreg 1 "África" 2 "Asia" 3 "Europa" 4 "América Latina y el Caribe" ///
                  5 "Norteamérica" 6 "Oceanía" ///
                  11 "Ingreso alto" 12 "Ingreso medio-alto" ///
                  13 "Ingreso medio-bajo" 14 "Ingreso bajo"

*--- 1a. Region of each country, via the parent chain: country -> subregion -> region
preserve
    keep if loctypename == "Subregion"
    keep locid parentid
    duplicates drop
    rename parentid reg_sub        // region that contains the subregion
    rename locid    parentid       // so it can be merged onto countries' parentid
    tempfile sub
    save `sub'
restore
merge m:1 parentid using `sub', keep(master match) nogen

gen int reg_id = .
replace reg_id = reg_sub  if loctypename == "Country/Area" & !missing(reg_sub)
* 5 countries hang directly from UN code 918 (Northern America):
* Bermuda, Canada, Greenland, Saint Pierre and Miquelon, USA
replace reg_id = 918      if loctypename == "Country/Area" & missing(reg_sub) & parentid == 918
replace reg_id = locid    if loctypename == "Geographic region"
* 5505 = "Americas" (Latin America + Northern America) is dropped: it would double count
recode reg_id (903=1) (935=2) (908=3) (904=4) (905=5) (909=6) (918=5) (5505=.), gen(region)
label values region lreg
label var region "Región"

*--- 1b. Type of row: 1 = country, 2 = regional aggregate, 3 = income-group aggregate
gen byte grp = region if loctypename == "Geographic region"
replace grp = 11 if location == "High-income countries"
replace grp = 12 if location == "Upper-middle-income countries"
replace grp = 13 if location == "Lower-middle-income countries"
replace grp = 14 if location == "Low-income countries"
* (the overlapping rows "Middle-income", "Low-and-middle-income", etc. are NOT used)
label values grp lreg
label var grp "Grupo (región o ingreso)"

gen byte tipo = .
replace tipo = 1 if loctypename == "Country/Area"
replace tipo = 2 if loctypename == "Geographic region"  & !missing(grp)
replace tipo = 3 if loctypename == "Income group"       & !missing(grp)

assert !missing(region) if tipo == 1          // every country got a region
assert !missing(cnmr)   if inlist(tipo,1,2,3) // no hole left after dropping 2101

*--- 1c. VALIDATION: sum of countries must equal the World row, every year
preserve
    gen double pob_paises = tpopulation1july if tipo == 1
    gen double pob_mundo  = tpopulation1july if location == "World"
    collapse (sum) pob_paises pob_mundo, by(time)
    gen ratio = pob_paises / pob_mundo
    summarize ratio
    display as result "Countries / World ratio: min " %9.7f r(min) "  max " %9.7f r(max)
    assert abs(ratio - 1) < 0.0001
restore
* Methodology sentence for the write-up:
*   "Analysis uses the 237 Country/Area rows (ISO3 present); their population sums
*    to the World total in every year (ratio = 1.0000)."

*--- 1d. Variable labels used in graphs
label var tfr           "Tasa global de fecundidad (hijos por mujer)"
label var lex           "Esperanza de vida al nacer (años)"
label var medianagepop  "Edad mediana (años)"
label var cbr           "Tasa bruta de natalidad (por 1.000)"
label var cdr           "Tasa bruta de mortalidad (por 1.000)"
label var cnmr          "Tasa de migración neta (por 1.000)"
label var natchangert   "Cambio natural (por 1.000)"
label var popgrowthrate "Crecimiento poblacional (% anual)"
label var popdensity    "Densidad poblacional (hab/km²)"

*--- 1e. Save three working files
preserve
    keep if tipo == 1
    save "$out/paises.dta", replace
restore
preserve
    keep if inlist(tipo,2,3)
    save "$out/grupos.dta", replace
restore

use "$out/paises.dta", clear
tab region if time == 2024
display as result "Countries in file: " _N/151

*------------------------------------------------------------------------------
* 2. Q1 - AGE STRUCTURE: median age by region (1950-2100)
*------------------------------------------------------------------------------
use "$out/grupos.dta", clear
keep if tipo == 2

local plots ""
local leg ""
forvalues r = 1/6 {
    local plots `plots' (line medianagepop time if region==`r', lcolor("${c`r'}") lwidth(medthick))
    local lab : label lreg `r'
    local leg `leg' `r' "`lab'"
}
twoway `plots', ///
    title("Edad mediana por región, 1950-2100") ///
    subtitle("Envejecimiento a distinto ritmo según la región", size(medsmall)) ///
    note("$fuente", size(vsmall)) ///
    xline(2023.5, lpattern(dash) lcolor(gs10)) ///
    xlabel(1950(25)2100, labsize(small)) ylabel(10(10)50, angle(0) grid glcolor(gs15)) ///
    xtitle("Año") ytitle("Edad mediana (años)") ///
    legend(order(`leg') rows(2) position(6) size(small)) ///
    graphregion(color(white)) plotregion(color(white)) name(g01, replace)
gexp g01_edad_mediana_regiones

* Gap between the oldest and the youngest region
bysort time: egen max_edad = max(medianagepop)
bysort time: egen min_edad = min(medianagepop)
gen brecha = max_edad - min_edad
label var brecha "Brecha de edad mediana (años)"
quietly summarize brecha if region == 1
local mx = r(max)
display as result "Largest regional gap in median age:"
list time brecha if region == 1 & brecha >= `mx' - 0.0001, noobs

twoway line brecha time if region == 1, lcolor("0 114 178") lwidth(thick) ///
    title("Brecha de edad mediana entre la región más envejecida y la más joven") ///
    note("$fuente", size(vsmall)) ///
    xline(2023.5, lpattern(dash) lcolor(gs10)) ///
    xlabel(1950(25)2100, labsize(small)) ylabel(, angle(0) grid glcolor(gs15)) ///
    xtitle("Año") ytitle("Años de diferencia") ///
    graphregion(color(white)) plotregion(color(white)) name(g02, replace)
gexp g02_brecha_edad_mediana

*------------------------------------------------------------------------------
* 3. Q4 - MIGRATION vs NATURAL CHANGE by region
*    Identity used: growth (%) = (natural change + net migration) / 10, per 1,000
*------------------------------------------------------------------------------
use "$out/grupos.dta", clear
keep if tipo == 2

* Check the identity on the aggregates (tolerance 0.01 percentage points)
gen chk = popgrowthrate - (natchangert + cnmr)/10
assert abs(chk) < 0.01
drop chk

* Panel per region with FREE y-scale: migration is tiny next to natural change
twoway (line natchangert time, lcolor("$c2") lwidth(medthick)) ///
       (line cnmr time,        lcolor("$c1") lwidth(medthick)), ///
    by(region, cols(3) yrescale ///
       title("Componentes del crecimiento poblacional por región") ///
       subtitle("Cambio natural vs. migración neta (por 1.000 habitantes; escala propia por panel)", size(medsmall)) ///
       note("$fuente", size(vsmall)) graphregion(color(white))) ///
    subtitle(, size(medsmall) nobox) ///
    yline(0, lpattern(dash) lcolor(gs8)) xline(2023.5, lpattern(shortdash) lcolor(gs10)) ///
    xlabel(1950 2000 2050 2100, labsize(small)) ylabel(, angle(0) labsize(small) grid glcolor(gs15)) ///
    xtitle("Año") ytitle("Tasa por 1.000 habitantes") ///
    legend(order(1 "Cambio natural" 2 "Migración neta") rows(1) position(6)) name(g03, replace)
gexp g03_cambio_natural_vs_migracion

* Total growth rate, all regions together
local plots ""
local leg ""
forvalues r = 1/6 {
    local plots `plots' (line popgrowthrate time if region==`r', lcolor("${c`r'}") lwidth(medthick))
    local lab : label lreg `r'
    local leg `leg' `r' "`lab'"
}
twoway `plots', ///
    title("Tasa de crecimiento poblacional por región, 1950-2100") ///
    note("$fuente", size(vsmall)) ///
    yline(0, lpattern(dash) lcolor(gs8)) xline(2023.5, lpattern(dash) lcolor(gs10)) ///
    xlabel(1950(25)2100, labsize(small)) ylabel(, angle(0) grid glcolor(gs15)) ///
    xtitle("Año") ytitle("Crecimiento anual (%)") ///
    legend(order(`leg') rows(2) position(6) size(small)) ///
    graphregion(color(white)) plotregion(color(white)) name(g04, replace)
gexp g04_crecimiento_regiones

* Table for the write-up
foreach y in 1950 2000 2024 2050 2100 {
    display as result _newline "Year `y'"
    tabstat natchangert cnmr popgrowthrate if time == `y' & tipo == 2, by(region) stat(mean) format(%6.2f)
}

*------------------------------------------------------------------------------
* 4. Q5 - COMPOSITE DEMOGRAPHIC INDEX (countries only)
*    Index = mean of 5 pooled z-scores: log density, life expectancy, median age,
*            net migration (winsorised 1/99), and INVERTED fertility.
*    Reading: higher = denser, longer-lived, older, net-immigration, low fertility
*             ("demographic maturity").
*    Fixes vs the earlier version: log(density) and winsorised migration so that
*    Monaco/Macao and Kuwait 1990 do not dominate. PCA index kept as a check.
*------------------------------------------------------------------------------
use "$out/paises.dta", clear

gen double ld = ln(popdensity)
label var ld "Log de la densidad poblacional"

_pctile cnmr, p(1 99)
gen double cnmr_w = min(max(cnmr, r(r1)), r(r2))
label var cnmr_w "Migración neta winsorizada (1%-99%)"

foreach v in ld lex medianagepop cnmr_w tfr {
    quietly summarize `v'
    gen double z_`v' = (`v' - r(mean)) / r(sd)
}
gen double z_tfr_inv = -z_tfr

gen double indice = (z_ld + z_lex + z_medianagepop + z_cnmr_w + z_tfr_inv) / 5
label var indice "Índice demográfico (promedio de 5 z-scores)"

* Robustness: first principal component of the same five components
pca z_ld z_lex z_medianagepop z_cnmr_w z_tfr_inv, components(1)
predict double indice_pca, score
quietly correlate indice indice_pca
if r(rho) < 0 replace indice_pca = -indice_pca     // orient: higher = more mature
label var indice_pca "Índice demográfico (1er componente principal)"
spearman indice indice_pca if time == 2024

save "$out/paises_indice.dta", replace

*--- 4a. Distribution of the index in 2024 (one point per country: independent obs)
twoway (histogram indice if time == 2024, bin(25) fcolor("0 114 178") lcolor(white)) ///
       (kdensity indice if time == 2024, lcolor("213 94 0") lwidth(medthick)), ///
    title("Distribución del índice demográfico, 2024") ///
    subtitle("237 países y áreas", size(medsmall)) ///
    note("Fuente: ONU, WPP 2024. Índice = promedio de 5 z-scores (ver metodología).", size(vsmall)) ///
    xtitle("Valor del índice") ytitle("Densidad") ///
    legend(order(1 "Histograma" 2 "Densidad kernel") rows(1) position(6)) ///
    graphregion(color(white)) plotregion(color(white)) name(g05, replace)
gexp g05_distribucion_indice_2024

*--- 4b. Top 15 and Bottom 15 (rule: population >= 1 million in 2024)
preserve
    keep if time == 2024 & tpopulation1july >= 1000
    gsort -indice
    keep in 1/15
    graph hbar indice, over(location, sort(1) descending label(labsize(small))) ///
        bar(1, color("0 114 178")) blabel(bar, format(%4.2f) size(small)) ///
        title("15 países con mayor índice demográfico, 2024") ///
        subtitle("Solo países con 1 millón de habitantes o más", size(medsmall)) ///
        ytitle("Valor del índice") note("Fuente: ONU, WPP 2024.", size(vsmall)) ///
        graphregion(color(white)) name(g06, replace)
    gexp g06_top15_indice_2024
restore

preserve
    keep if time == 2024 & tpopulation1july >= 1000
    gsort indice
    keep in 1/15
    graph hbar indice, over(location, sort(1) label(labsize(small))) ///
        bar(1, color("213 94 0")) blabel(bar, format(%4.2f) size(small)) ///
        title("15 países con menor índice demográfico, 2024") ///
        subtitle("Solo países con 1 millón de habitantes o más", size(medsmall)) ///
        ytitle("Valor del índice") note("Fuente: ONU, WPP 2024.", size(vsmall)) ///
        graphregion(color(white)) name(g07, replace)
    gexp g07_bottom15_indice_2024
restore

*--- 4c. Quadrant scatter: level in 2024 vs change 2000-2024
preserve
    keep if inlist(time, 2000, 2024)
    keep iso3_code location region time indice
    reshape wide indice, i(iso3_code) j(time)
    gen cambio = indice2024 - indice2000
    label var cambio "Cambio del índice (2024 - 2000)"

    quietly summarize cambio, detail
    local mx = r(p50)
    local xmin = r(min)
    local xmax = r(max)
    quietly summarize indice2024, detail
    local my = r(p50)
    local ymin = r(min)
    local ymax = r(max)

    * label only the extreme countries (5 lowest / 5 highest on each axis)
    egen r_x = rank(cambio)
    egen r_y = rank(indice2024)
    quietly count
    local N = r(N)
    gen lab = iso3_code if r_x <= 5 | r_x >= `N'-4 | r_y <= 5 | r_y >= `N'-4

    local plots ""
    local leg ""
    forvalues r = 1/6 {
        local plots `plots' (scatter indice2024 cambio if region==`r', mcolor("${c`r'}") msymbol(O) msize(small) mlabel(lab) mlabsize(vsmall) mlabcolor(gs5))
        local lab2 : label lreg `r'
        local leg `leg' `r' "`lab2'"
    }
    twoway `plots', ///
        yline(`my', lpattern(dash) lcolor(gs10)) xline(`mx', lpattern(dash) lcolor(gs10)) ///
        text(`ymax' `xmax' "Alto nivel y en ascenso", place(sw) size(small) color(gs6)) ///
        text(`ymax' `xmin' "Alto nivel, ascenso lento", place(se) size(small) color(gs6)) ///
        text(`ymin' `xmax' "Bajo nivel, ascenso rápido", place(nw) size(small) color(gs6)) ///
        text(`ymin' `xmin' "Bajo nivel y rezagado", place(ne) size(small) color(gs6)) ///
        title("Matriz de tipologías demográficas") ///
        subtitle("Nivel del índice en 2024 vs. cambio 2000-2024 (líneas = medianas)", size(medsmall)) ///
        note("Fuente: ONU, WPP 2024. Se rotulan solo los países extremos.", size(vsmall)) ///
        xtitle("Cambio del índice (2024 - 2000)") ytitle("Índice demográfico 2024") ///
        legend(order(`leg') rows(2) position(6) size(small)) ///
        graphregion(color(white)) plotregion(color(white)) name(g08, replace)
    gexp g08_tipologias_cuadrantes
restore

*--- 4d. Index over time by region (population-weighted mean of its countries)
preserve
    collapse (mean) indice [aw = tpopulation1july], by(region time)
    local plots ""
    local leg ""
    forvalues r = 1/6 {
        local plots `plots' (line indice time if region==`r', lcolor("${c`r'}") lwidth(medthick))
        local lab : label lreg `r'
        local leg `leg' `r' "`lab'"
    }
    twoway `plots', ///
        title("Evolución del índice demográfico por región, 1950-2100") ///
        subtitle("Promedio ponderado por población", size(medsmall)) ///
        note("$fuente", size(vsmall)) ///
        xline(2023.5, lpattern(dash) lcolor(gs10)) ///
        xlabel(1950(25)2100, labsize(small)) ylabel(, angle(0) grid glcolor(gs15)) ///
        xtitle("Año") ytitle("Índice demográfico") ///
        legend(order(`leg') rows(2) position(6) size(small)) ///
        graphregion(color(white)) plotregion(color(white)) name(g09, replace)
    gexp g09_indice_por_region
restore

*------------------------------------------------------------------------------
* 5. Q6 - GROUPS OF COUNTRIES BY HOW THEIR INDICATORS MOVE OVER TIME
*    k-means on 237 countries (aggregates excluded). Features: fertility, life
*    expectancy and median age at 1960, 1990, 2024, 2050, 2075 + mean net
*    migration 1990-2023. Previous version clustered density only and included
*    318 aggregates, giving groups of 550/3/2.
*------------------------------------------------------------------------------
use "$out/paises_indice.dta", clear

preserve
    keep if inlist(time, 1960, 1990, 2024, 2050, 2075)
    keep iso3_code location region time tfr lex medianagepop
    reshape wide tfr lex medianagepop, i(iso3_code) j(time)
    tempfile feat
    save `feat'
restore

preserve
    keep if inrange(time, 1990, 2023)
    collapse (mean) mig = cnmr_w, by(iso3_code)
    merge 1:1 iso3_code using `feat', assert(match) nogen
    label var mig "Migración neta media 1990-2023 (por 1.000)"

    * standardise every feature so none dominates
    unab feats : tfr* lex* medianagepop* mig
    foreach v of local feats {
        egen z_`v' = std(`v')
    }
    unab zs : z_*

    *--- 5a. Choosing k: Calinski-Harabasz pseudo-F (higher = better separated)
    quietly count
    local N = r(N)
    local p : word count `zs'
    forvalues k = 2/6 {
        quietly cluster kmeans `zs', k(`k') start(prandom(12345)) gen(g`k')
        gen double wss = 0
        foreach z of local zs {
            bysort g`k': egen double m_ = mean(`z')
            replace wss = wss + (`z' - m_)^2
            drop m_
        }
        quietly summarize wss
        local W = r(sum)
        local TSS = (`N' - 1) * `p'
        local CH = ((`TSS' - `W') / (`k' - 1)) / (`W' / (`N' - `k'))
        display as result "k = `k'   Calinski-Harabasz = " %7.1f `CH'
        drop wss
    }
    * Pick $K in section 0 using the table above. In our test k=2 had the highest
    * pseudo-F and k=3 was next; k=3 gives a more informative typology.

    *--- 5b. Final clustering, relabelled by median age 2024 (group 1 = youngest)
    cluster kmeans `zs', k($K) start(prandom(12345)) gen(g_raw)
    bysort g_raw: egen m_edad = mean(medianagepop2024)
    egen grupo = group(m_edad)
    forvalues i = 1/$K {
        quietly summarize medianagepop2024 if grupo == `i'
        local m = string(r(mean), "%2.0f")
        label define lgrp `i' "Grupo `i' (edad mediana 2024 ≈ `m' años)", add
    }
    label values grupo lgrp
    label var grupo "Grupo demográfico (k-means)"

    display as result _newline "Group sizes and composition by region:"
    tab grupo
    tab region grupo, row
    tabstat tfr2024 lex2024 medianagepop2024 mig, by(grupo) stat(mean n) format(%6.2f)

    * cluster map in 2024 (fertility vs life expectancy)
    local plots ""
    local leg ""
    forvalues i = 1/$K {
        local plots `plots' (scatter lex2024 tfr2024 if grupo==`i', mcolor("${gp`i'}") msymbol(O) msize(small))
        local lab : label lgrp `i'
        local leg `leg' `i' "`lab'"
    }
    twoway `plots', ///
        title("Grupos demográficos de países, 2024") ///
        subtitle("Fecundidad vs. esperanza de vida (k-means sobre trayectorias 1960-2075)", size(medsmall)) ///
        note("Fuente: ONU, WPP 2024. 237 países y áreas.", size(vsmall)) ///
        xtitle("Tasa global de fecundidad (hijos por mujer)") ytitle("Esperanza de vida al nacer (años)") ///
        legend(order(`leg') rows(3) position(6) size(small)) ///
        graphregion(color(white)) plotregion(color(white)) name(g10, replace)
    gexp g10_grupos_mapa_2024

    keep iso3_code location region grupo
    save "$out/clusters.dta", replace
    export delimited using "$out/clusters_paises.csv", replace
restore

*--- 5c. Average trajectories of each group
use "$out/paises_indice.dta", clear
merge m:1 iso3_code using "$out/clusters.dta", assert(match) nogen keepusing(grupo)
collapse (mean) tfr lex medianagepop cnmr_w, by(grupo time)

local first = 1
foreach v in tfr lex medianagepop {
    local plots ""
    local leg ""
    forvalues i = 1/$K {
        local plots `plots' (line `v' time if grupo==`i', lcolor("${gp`i'}") lwidth(medthick))
        local lab : label lgrp `i'
        local leg `leg' `i' "`lab'"
    }
    local lt : variable label `v'
    local lg legend(off)
    if `first' == 1 local lg legend(order(`leg') cols(1) position(6) size(vsmall))
    twoway `plots', title("`lt'", size(medsmall)) xline(2023.5, lpattern(dash) lcolor(gs10)) ///
        xlabel(1960(40)2100, labsize(small)) ylabel(, angle(0) grid glcolor(gs15)) ///
        xtitle("Año") ytitle("") `lg' ///
        graphregion(color(white)) plotregion(color(white)) name(gc_`v', replace)
    local first = 0
}
graph combine gc_tfr gc_lex gc_medianagepop, cols(3) ///
    title("Trayectorias promedio de los grupos demográficos") ///
    note("$fuente", size(vsmall)) graphregion(color(white)) name(g11, replace)
gexp g11_grupos_trayectorias

*------------------------------------------------------------------------------
* 6. Q7 - HOW FERTILITY, MORTALITY AND MIGRATION COMBINE TO SHAPE GROWTH
*    Exact identity:  growth (%) = (CBR - CDR + CNMR) / 10
*    Regions (6) and income groups (4, mutually exclusive) from the UN aggregates.
*------------------------------------------------------------------------------
use "$out/grupos.dta", clear

gen chk = popgrowthrate - (cbr - cdr + cnmr)/10
assert abs(chk) < 0.01
drop chk
gen crec_1000 = popgrowthrate * 10
label var crec_1000 "Crecimiento total (por 1.000)"

*--- 6a. Births, deaths, net migration and total growth over time
foreach s in reg inc {
    local cond "grp < 10"
    local cols 3
    local ttl "región"
    if "`s'" == "inc" local cond "grp > 10"
    if "`s'" == "inc" local cols 2
    if "`s'" == "inc" local ttl "grupo de ingreso"
    twoway (line cbr time,       lcolor("0 114 178") lwidth(medthick)) ///
           (line cdr time,       lcolor("213 94 0")  lwidth(medthick)) ///
           (line cnmr time,      lcolor("0 158 115") lwidth(medthick)) ///
           (line crec_1000 time, lcolor(black) lwidth(medthick) lpattern(dash)) ///
           if `cond', ///
        by(grp, cols(`cols') ///
           title("Natalidad, mortalidad y migración por `ttl'") ///
           subtitle("Crecimiento = natalidad - mortalidad + migración neta (por 1.000 habitantes)", size(small)) ///
           note("$fuente", size(vsmall)) graphregion(color(white))) ///
        subtitle(, size(medsmall) nobox) ///
        yline(0, lpattern(dash) lcolor(gs8)) xline(2023.5, lpattern(shortdash) lcolor(gs10)) ///
        xlabel(1950 2000 2050 2100, labsize(small)) ylabel(, angle(0) labsize(small) grid glcolor(gs15)) ///
        xtitle("Año") ytitle("Por 1.000 habitantes") ///
        legend(order(1 "Natalidad (CBR)" 2 "Mortalidad (CDR)" 3 "Migración neta" 4 "Crecimiento total") ///
               rows(1) position(6) size(small)) name(g12_`s', replace)
    gexp g12_componentes_`s'
}

*--- 6b. Contribution of natural change and migration to growth (2024 and 2050)
gen aporte_nat = natchangert / 10
gen aporte_mig = cnmr / 10
label var aporte_nat "Cambio natural"
label var aporte_mig "Migración neta"
foreach y in 2024 2050 {
    graph hbar (asis) aporte_nat aporte_mig if time == `y', over(grp, label(labsize(small))) stack ///
        bar(1, color("0 114 178")) bar(2, color("0 158 115")) ///
        title("Aporte al crecimiento poblacional, `y'") ///
        subtitle("Puntos porcentuales por año", size(medsmall)) ///
        ytitle("Crecimiento anual (%)") ///
        note("Fuente: ONU, WPP 2024. 2050 es proyección.", size(vsmall)) ///
        legend(order(1 "Cambio natural" 2 "Migración neta") rows(1) position(6)) ///
        graphregion(color(white)) name(g13_`y', replace)
    gexp g13_aporte_crecimiento_`y'
}

*--- 6c. Summary table for the write-up
foreach y in 1950 1975 2000 2024 2050 2100 {
    display as result _newline "Year `y'"
    tabstat cbr cdr cnmr popgrowthrate if time == `y', by(grp) stat(mean) format(%6.2f)
}

*--- 6d. Which component explains differences in growth ACROSS COUNTRIES (2023)?
*    Because growth = a_nat + a_mor + a_mig, the slope of each component on growth
*    is its share of the variance of growth (the three shares add up to 1).
*    CBR is used as the fertility channel and CDR as the mortality channel.
use "$out/paises.dta", clear
keep if time == 2023
gen a_nat =  cbr  / 10
gen a_mor = -cdr  / 10
gen a_mig =  cnmr / 10

tempname P
tempfile res
postfile `P' region double(sh_nat sh_mor sh_mig n) using `res', replace
forvalues r = 0/6 {
    foreach v in a_nat a_mor a_mig {
        if `r' == 0 quietly regress `v' popgrowthrate
        else        quietly regress `v' popgrowthrate if region == `r'
        local b_`v' = _b[popgrowthrate]
    }
    quietly count if `r' == 0 | region == `r'
    post `P' (`r') (`b_a_nat') (`b_a_mor') (`b_a_mig') (r(N))
}
postclose `P'

use `res', clear
label define lregx 0 "Todos los países" 1 "África" 2 "Asia" 3 "Europa" ///
                   4 "América Latina y el Caribe" 5 "Norteamérica (n=5)" 6 "Oceanía"
label values region lregx
label var sh_nat "Natalidad"
label var sh_mor "Mortalidad"
label var sh_mig "Migración"
list region n sh_nat sh_mor sh_mig, noobs sep(0)

graph hbar (asis) sh_nat sh_mor sh_mig, over(region, label(labsize(small))) stack ///
    bar(1, color("0 114 178")) bar(2, color("213 94 0")) bar(3, color("0 158 115")) ///
    title("¿Qué explica las diferencias de crecimiento entre países? (2023)") ///
    subtitle("Parte de la varianza del crecimiento atribuible a cada componente", size(medsmall)) ///
    ytitle("Participación en la varianza (suma = 1)") ///
    note("Fuente: ONU, WPP 2024. Participación = cov(componente, crecimiento)/var(crecimiento).", size(vsmall)) ///
    legend(order(1 "Natalidad (CBR)" 2 "Mortalidad (CDR)" 3 "Migración neta") rows(1) position(6)) ///
    graphregion(color(white)) name(g14, replace)
gexp g14_varianza_crecimiento_2023

*------------------------------------------------------------------------------
* 7. Q8 - IS ONE INDICATOR ENOUGH?
*------------------------------------------------------------------------------
use "$out/paises_indice.dta", clear
keep if time == 2023

pwcorr popgrowthrate tfr lex medianagepop cnmr ld, sig

* R-squared of explaining growth with each single indicator vs. all together
tempname P2
tempfile res2
postfile `P2' str60 indicador double(r2) using `res2', replace
foreach v in tfr lex medianagepop cnmr ld {
    quietly regress popgrowthrate `v'
    local nm : variable label `v'
    post `P2' ("`nm'") (e(r2))
}
quietly regress popgrowthrate tfr lex medianagepop cnmr ld
post `P2' ("Los cinco juntos") (e(r2))
postclose `P2'

* Principal components of the five indicators (how many dimensions are there?)
pca z_ld z_lex z_medianagepop z_cnmr_w z_tfr_inv
screeplot, yline(1, lpattern(dash) lcolor(gs10)) ///
    title("Componentes principales de los cinco indicadores (2023)") ///
    note("Fuente: ONU, WPP 2024. Un solo componente no resume los cinco indicadores.", size(vsmall)) ///
    graphregion(color(white)) name(g15, replace)
gexp g15_screeplot_indicadores

use `res2', clear
graph hbar r2, over(indicador, sort(1) descending label(labsize(small))) ///
    bar(1, color("0 114 178")) blabel(bar, format(%4.2f) size(small)) ///
    title("¿Cuánto del crecimiento explica cada indicador por separado? (2023)") ///
    subtitle("R² de una regresión simple vs. el modelo con todos", size(medsmall)) ///
    ytitle("R²") note("Fuente: ONU, WPP 2024. 237 países y áreas.", size(vsmall)) ///
    graphregion(color(white)) name(g16, replace)
gexp g16_r2_indicadores

*------------------------------------------------------------------------------
display as result _newline "DONE. Graphs, tables and the log are in: $out"
log close
