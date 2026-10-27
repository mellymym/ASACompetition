* ===== LIMPIEZA (correr una vez) =====
keep if loctypename == "Geographic region"
keep if inlist(location, "Africa","Asia","Europe", ///
    "Latin America and the Caribbean","Northern America")
drop if missing(time) | time > 2100
isid location time          

capture drop region 
gen region = location
replace region = "África"       if location=="Africa"
replace region = "Europa"       if location=="Europe"
replace region = "Am. Latina y el Caribe" if location=="Latin America and the Caribbean"
replace region = "Norteamérica" if location=="Northern America"
sort region time

* GRÁFICA 1
twoway (line natchangert time, lcolor("31 119 180") lwidth(medthick)) ///
       (line cnmr time, lcolor("230 85 13") lwidth(medthick)), ///
  by(region, cols(3) iscale(*.9) ixaxes ixlabel ixtitle ///
     title("Componentes del crecimiento poblacional") ///
     subtitle("Cambio natural vs. migración neta (por 1.000 hab.)", size(medsmall)) ///
     note("Fuente: ONU, World Population Prospects. Línea punteada vertical: inicio de proyecciones.", size(vsmall)) ///
     graphregion(color(white))) ///
  subtitle(, size(medsmall) fcolor(gs14) nobox) ///
  yline(0, lpattern(dash) lcolor(gs8)) ///
  xline(2023.5, lpattern(shortdash) lcolor(gs10)) ///
  xlabel(1950 2000 2050 2100, labsize(small)) ///
  ylabel(-10(10)30, angle(0) labsize(small) grid glcolor(gs15)) ///
  xtitle("Año") ytitle("Tasa por 1.000 habitantes") ///
  legend(order(1 "Cambio natural" 2 "Migración neta") rows(1) position(6)) ///
  name(graf1, replace)

graph export "grafica1_migracion_vs_crecimiento.png", width(2400) replace

* GRÁFICA 2
twoway (line medianagepop time if region=="África",       lcolor("214 39 40")  lwidth(thick)) ///
       (line medianagepop time if region=="Asia",         lcolor("31 119 180") lwidth(thick)) ///
       (line medianagepop time if region=="Europa",       lcolor("44 160 44")  lwidth(thick)) ///
       (line medianagepop time if region=="Am. Latina y el Caribe", lcolor("255 127 14") lwidth(thick)) ///
       (line medianagepop time if region=="Norteamérica", lcolor("148 103 189") lwidth(thick)), ///
  title("Evolución y divergencia de la edad mediana (1950–2100)") ///
  note("Fuente: ONU, World Population Prospects. Línea punteada: inicio de proyecciones.", size(vsmall)) ///
  xline(2023.5, lpattern(shortdash) lcolor(gs10)) ///
  xlabel(1950(25)2100) ylabel(10(10)50, angle(0) grid glcolor(gs15)) ///
  xtitle("Año") ytitle("Edad mediana (años)") ///
  legend(order(1 "África" 2 "Asia" 3 "Europa" 4 "América Latina" 5 "Norteamérica") ///
         rows(1) position(6) size(small)) ///
  graphregion(color(white)) plotregion(color(white)) ///
  name(graf2, replace)

graph export "grafica2_divergencia_edad_mediana.png", width(2400) replace