* FIRST
ssc install corrplot, replace
* Stata lowercases variable names on import. Check what you got:
describe
rename *, lower

* Blank ISO3 = aggregate. Strip whitespace first so " " counts as missing
replace iso3_code = strtrim(iso3_code)
gen byte is_country = !missing(iso3_code)

tab loctypename is_country

gen byte is_country2 = (locid < 900)
tab is_country is_country2

* Inspect disagreements by hand
list location iso3_code loctypename locid if is_country != is_country2 & time==2023, sepby(location) noobs

* SECOND

* Keep only the countries
keep if is_country==1

* Check: the countries must add up to the World total, year by year
* (reload the data first, because "keep" removed the World rows)
import delimited "C:\Users\Asus\Desktop\ASACompetition\WPP2024_Demographic_Indicators_Medium.csv", clear
gen byte is_country = (locid < 900)
gen double pop_c = tpopulation1july if is_country==1
gen double pop_w = tpopulation1july if location=="World"
preserve
collapse (sum) pop_c pop_w, by(time)
gen ratio = pop_c/pop_w
summarize ratio
list time ratio if abs(ratio-1) > 0.0001
restore

* Now keep only the countries and save
keep if is_country==1
drop if time > 2100
save "C:\Users\Asus\Desktop\ASACompetition\wpp_countries.dta", replace


/* THIRD
preserve
gen double pop_c = `pop' if is_country==1
gen double pop_w = `pop' if location=="World"
collapse (sum) pop_c pop_w, by(time)
gen ratio = pop_c/pop_w
summarize ratio
list time ratio if abs(ratio-1) > 0.01
restore */