set processors 16
dis c(processors)

*-------------------------------------------------------------------------------
* Use aggregate index data
cd "D:\Project C\aggregate index"
import excel ".\CN EER Index.xlsx", sheet("Sheet1") firstrow clear
save CN_EER_index,replace

use "D:\Project C\PWT10.0\pwt100.dta", clear
keep if countrycode=="CHN"
keep year xr rgdpna pl_c pl_x pl_m
merge n:1 year using CN_EER_index, nogen keep(matched)
gen pcost=NEER_index*pl_c/REER_index
gen dlnprice_exp=ln(pl_x)-ln(pl_x[_n-1]) if year==year[_n-1]+1
gen dlnprice_imp=ln(pl_m)-ln(pl_m[_n-1]) if year==year[_n-1]+1
gen dlnREER=ln(REER_index)-ln(REER_index[_n-1]) if year==year[_n-1]+1
gen dlnpcost=ln(pcost)-ln(pcost[_n-1]) if year==year[_n-1]+1
gen dlnrgdp=ln(rgdpna)-ln(rgdpna[_n-1]) if year==year[_n-1]+1
save CN_index_94_19,replace

use CN_index_94_19,clear
gen period=1 if year<=2007
replace period=2 if year>2007
reg dlnprice_exp dlnREER dlnpcost dlnrgdp
reg dlnprice_imp dlnREER dlnpcost dlnrgdp
forv i=1/2{
eststo reg_index_exp_`i': reg dlnprice_exp dlnREER dlnpcost dlnrgdp if period==`i'
eststo reg_index_imp_`i': reg dlnprice_imp dlnREER dlnpcost dlnrgdp if period==`i'
}

*-------------------------------------------------------------------------------
* Construct exchange rate from PWT10.0
cd "D:\Project C\PWT10.0"
use PWT100,clear
keep countrycode country currency_unit
duplicates drop
merge 1:1 countrycode using "D:\Project A\ER_GEM\country_name",nogen keep(matched master)
replace coun_aim="安圭拉" if countrycode=="AIA"
replace coun_aim="库拉索" if countrycode=="CUW"
replace coun_aim="黑山" if countrycode=="MNE"
replace coun_aim="蒙特塞拉特" if countrycode=="MSR"
replace coun_aim="巴勒斯坦" if countrycode=="PSE"
replace coun_aim="塞尔维亚" if countrycode=="SRB"
replace coun_aim="荷属圣马丁" if countrycode=="SXM"
replace coun_aim="特克斯和凯科斯群岛" if countrycode=="TCA"
replace coun_aim="土库曼斯坦" if countrycode=="TKM"
replace coun_aim="英属维尔京群岛" if countrycode=="VGB"
replace coun_aim="刚果民主共和国" if countrycode=="COD"
save country_name,replace

cd "D:\Project C\PWT10.0"
use PWT100,clear
keep if year>=1999 & year<=2011 
keep countrycode country currency_unit year xr pl_c rgdpna
merge n:1 countrycode country currency_unit using country_name,nogen
* Bilateral nominal exchange rate relative to RMB at the same year
gen NER=1/(xr/8.27825) if year==1999
replace NER=8.2785042/xr if year==2000
replace NER=8.2770683/xr if year==2001
replace NER=8.2769575/xr if year==2002
replace NER=8.2770367/xr if year==2003
replace NER=8.2768008/xr if year==2004
replace NER=8.1943167/xr if year==2005
replace NER=7.9734383/xr if year==2006
replace NER=7.6075325/xr if year==2007
replace NER=6.948655/xr if year==2008
replace NER=6.8314161/xr if year==2009
replace NER=6.770269/xr if year==2010
replace NER=6.4614613/xr if year==2011
label var NER "Nominal exchange rate in terms of RMB at the same year"
* Bilateral real exchange rate = NER*foreign CPI/Chinese CPI
gen RER=NER*pl_c/.2097405 if year==1999
replace RER=NER*pl_c/.2201256 if year==2000
replace RER=NER*pl_c/.2265737 if year==2001
replace RER=NER*pl_c/.2242131 if year==2002
replace RER=NER*pl_c/.2326131 if year==2003
replace RER=NER*pl_c/.2451899 if year==2004
replace RER=NER*pl_c/.25580388 if year==2005
replace RER=NER*pl_c/.2772298 if year==2006
replace RER=NER*pl_c/.33112419 if year==2007
replace RER=NER*pl_c/.4083561 if year==2008
replace RER=NER*pl_c/.4175323 if year==2009
replace RER=NER*pl_c/.439816 if year==2010
replace RER=NER*pl_c/.49505907 if year==2011
label var RER "Real exchange rate to China price at the same year"
sort coun_aim year
by coun_aim: gen dlnRER= ln(RER)-ln(RER[_n-1]) if year==year[_n-1]+1
by coun_aim: gen dlnrgdp=ln(rgdpna)-ln(rgdpna[_n-1]) if year==year[_n-1]+1
save RER_99_11.dta,replace

cd "D:\Project C\PWT10.0"
use RER_99_11,clear
keep if countrycode=="USA"
keep year NER coun_aim
rename NER NER_US
save US_NER_99_11.dta,replace

cd "D:\Project C\PWT10.0"
use RER_99_11,clear
keep if countrycode=="USA" | countrycode=="KOR" | countrycode=="JPN" | countrycode=="GBR" |countrycode=="TWN"
gen NER_sd=100 if year==1999
replace NER_sd=NER*100/NER[_n-1] if year>=2000
gen RER_sd=100 if year==1999
replace RER_sd=RER*100/RER[_n-1] if year>=2000
keep currency_unit year NER_sd RER_sd
save RER_99_11_figure.dta,replace

*-------------------------------------------------------------------------------
* Use custom full data
cd "D:\Project C\customs data"
use tradedata_2000_concise,clear
forv i=2001/2011{
append using tradedata_`i'_concise
}
drop if value==0 | quantity==0 | party_id==""
drop CompanyType
sort party_id exp_imp HS8 coun_aim year
format EN %30s
format party_id coun_aim %15s
save customs_00-11.dta,replace

cd "D:\Project C\HS Conversion"
import excel "HS 2007 to HS 2002 Correlation and conversion tables.xls", sheet("Conversion Tables") cellrange(A2:B5054) firstrow allstring clear
save HS2007to2002.dta, replace
import excel "HS 2007 to HS 1996 Correlation and conversion tables.xls", sheet("Conversion Tables") cellrange(A2:B5054) firstrow allstring clear
save HS2007to1996.dta, replace
import excel "HS2002 to HS1996 - Correlation and conversion tables.xls", sheet("Conversion Table") cellrange(A2:B5225) firstrow allstring clear
save HS2002to1996.dta, replace

cd "D:\Project C\customs data"
use ".\customs_00-11.dta",clear
* Refer to the do-file "customs_country_clean" for program details
customs_country_clean
save customs_country_name,replace

cd "D:\Project C"
use ".\customs data\customs_00-11.dta",clear
bys party_id: egen EN_adj=mode(EN),maxmode
drop EN
rename EN_adj EN
merge n:1 coun_aim using ".\customs data\customs_country_name",nogen keep(matched)
drop coun_aim
rename country_adj coun_aim
drop if coun_aim==""|coun_aim=="中华人民共和国"
collapse (sum) value quant, by (party_id EN HS8 coun_aim year exp_imp)
gen HS2007=substr(HS8,1,6) if year>=2007
merge n:1 HS2007 using "D:\Project C\HS Conversion\HS2007to1996.dta",nogen update replace
gen HS2002=substr(HS8,1,6) if year<2007 & year>=2002
merge n:1 HS2002 using "D:\Project C\HS Conversion\HS2002to1996.dta",nogen update replace
replace HS1996=substr(HS8,1,6) if year<2002
rename HS1996 HS6
drop if HS6=="" | party_id==""
collapse (sum) value quant, by (party_id EN exp_imp HS6 coun_aim year)
order party_id EN exp_imp HS6 coun_aim year
format EN %30s
format coun_aim %15s
cd "D:\Project C\sample_all"
save customs_all,replace

*-------------------------------------------------------------------------------
* Construct top trade partners
cd "D:\Project C\sample_all"
use customs_all,clear
collapse (sum) value, by (coun_aim exp_imp)
gen value_exp=value if exp_imp=="exp"
gen value_imp=value if exp_imp=="imp"
collapse (sum) value_exp value_imp , by (coun_aim)
gsort -value_exp, gen(rank_exp)
gsort -value_imp, gen(rank_imp)
save customs_all_top_partners,replace

*-------------------------------------------------------------------------------
* Construct export sample
cd "D:\Project C\sample_all"
use customs_all,clear
keep if exp_imp =="exp"
drop exp_imp
foreach key in 贸易 外贸 经贸 工贸 科贸 商贸 边贸 技贸 进出口 进口 出口 物流 仓储 采购 供应链 货运{
	drop if strmatch(EN, "*`key'*") 
}
merge n:1 coun_aim using "D:\Project C\sample_all\customs_all_top_partners",nogen keep(matched)
sort party_id HS6 coun_aim year
by party_id HS6 coun_aim: egen year_count=count(year)
drop if year_count<=1
gen HS2=substr(HS6,1,2)
drop if HS2=="93"|HS2=="97"|HS2=="98"|HS2=="99"
merge n:1 year using "D:\Project C\PWT10.0\US_NER_99_11",nogen keep(matched)
merge n:1 year coun_aim using "D:\Project C\PWT10.0\RER_99_11.dta",nogen keep(matched) keepus(NER RER dlnRER dlnrgdp)
sort party_id HS6 coun_aim year
gen price_RMB=value*NER_US/quant
by party_id HS6 coun_aim: gen dlnprice=ln(price_RMB)-ln(price_RMB[_n-1]) if year==year[_n-1]+1
by party_id HS6 coun_aim: egen year_count=count(year)
drop if year_count<=1
winsor2 dlnprice, trim by(HS2 year)
egen group_id=group(party_id HS6 coun_aim)
save sample_all_exp,replace

cd "D:\Project C\sample_all"
use sample_all_exp,clear
eststo reg_all_exp: areg dlnprice_tr dlnRER dlnrgdp i.year, a(group_id)
eststo reg_top50_exp: areg dlnprice_tr dlnRER dlnrgdp i.year if rank_exp<=50, a(group_id)
eststo reg_top20_exp: areg dlnprice_tr dlnRER dlnrgdp i.year if rank_exp<=20, a(group_id)

estfe reg_all_exp reg_top50_exp reg_top20_exp, labels(group_id "Firm-product-country FE")
esttab reg_all_exp reg_top50_exp reg_top20_exp using "D:\Project C\tables\all\table_all_exp.csv", replace b(3) se(3) starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Whole" "Top 50" "Top 20")

forv i=2003/2009{
	eststo reg_all_exp_ma5_`i': areg dlnprice_tr dlnRER dlnrgdp i.year if year>=`i'-2 & year<=`i'+2, a(group_id)
}
estfe reg_all_exp_ma5_*, labels(group_id "Firm-product-country FE")
esttab reg_all_exp_ma5_* using "D:\Project C\tables\all\table_all_exp_ma5.csv", replace b(3) se(3) starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles( "03" "04" "05" "06" "07" "08" "09")

forv i=2002/2010{
	eststo reg_all_exp_ma3_`i': areg dlnprice_tr dlnRER dlnrgdp i.year if year>=`i'-1 & year<=`i'+1, a(group_id)
}
estfe reg_all_exp_ma3_*, labels(group_id "Firm-product-country FE")
esttab reg_all_exp_ma3_* using "D:\Project C\tables\all\table_all_exp_ma3.csv", replace b(3) se(3) starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles( "02" "03" "04" "05" "06" "07" "08" "09" "10")

*-------------------------------------------------------------------------------
* Construct import sample
cd "D:\Project C\sample_all"
use customs_all,clear
keep if exp_imp =="imp"
drop exp_imp
foreach key in 贸易 外贸 经贸 工贸 科贸 商贸 边贸 技贸 进出口 进口 出口 物流 仓储 采购 供应链 货运{
	drop if strmatch(EN, "*`key'*") 
}
merge n:1 coun_aim using "D:\Project C\sample_all\customs_all_top_partners",nogen keep(matched)
sort party_id HS6 coun_aim year
by party_id HS6 coun_aim: egen year_count=count(year)
drop if year_count<=1
gen HS2=substr(HS6,1,2)
drop if HS2=="93"|HS2=="97"|HS2=="98"|HS2=="99"
merge n:1 year using "D:\Project C\PWT10.0\US_NER_99_11",nogen keep(matched)
merge n:1 year coun_aim using "D:\Project C\PWT10.0\RER_99_11.dta",nogen keep(matched) keepus(NER RER dlnRER dlnrgdp)
sort party_id HS6 coun_aim year
gen price_RMB=value*NER_US/quant
by party_id HS6 coun_aim: gen dlnprice=ln(price_RMB)-ln(price_RMB[_n-1]) if year==year[_n-1]+1
by party_id HS6 coun_aim: egen year_count=count(year)
drop if year_count<=1
winsor2 dlnprice, trim by(HS2 year)
egen group_id=group(party_id HS6 coun_aim)
save sample_all_imp,replace

cd "D:\Project C\sample_all"
use sample_all_imp,clear
eststo reg_all_imp: areg dlnprice_tr dlnRER dlnrgdp i.year, a(group_id)
eststo reg_top50_imp: areg dlnprice_tr dlnRER dlnrgdp i.year if rank_imp<=50, a(group_id)
eststo reg_top20_imp: areg dlnprice_tr dlnRER dlnrgdp i.year if rank_imp<=20, a(group_id)

estfe reg_all_imp reg_top50_imp reg_top20_imp, labels(group_id "Firm-product-country FE")
esttab reg_all_imp reg_top50_imp reg_top20_imp using "D:\Project C\tables\all\table_all_imp.csv", replace b(3) se(3) starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Whole" "Top 50" "Top 20")

forv i=2003/2009{
	eststo reg_all_imp_ma5_`i': areg dlnprice_tr dlnRER dlnrgdp i.year if year>=`i'-2 & year<=`i'+2, a(group_id)
}
estfe reg_all_imp_ma5_*, labels(group_id "Firm-product-country FE")
esttab reg_all_imp_ma5_* using "D:\Project C\tables\all\table_all_imp_ma5.csv", replace b(3) se(3) starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles( "03" "04" "05" "06" "07" "08" "09")

forv i=2002/2010{
	eststo reg_all_imp_ma3_`i': areg dlnprice_tr dlnRER dlnrgdp i.year if year>=`i'-1 & year<=`i'+1, a(group_id)
}
estfe reg_all_imp_ma3_*, labels(group_id "Firm-product-country FE")
esttab reg_all_imp_ma3_* using "D:\Project C\tables\all\table_all_imp_ma3.csv", replace b(3) se(3) starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles( "02" "03" "04" "05" "06" "07" "08" "09" "10")

*-------------------------------------------------------------------------------
* Use custom matched data
cd "D:\Project C\sample_matched"
use "D:\Project A\customs merged\cust.matched.all.dta",clear
bys FRDM: egen EN_adj=mode(EN),maxmode
drop EN
rename EN_adj EN
merge n:1 coun_aim using "D:\Project A\customs merged\cust_country",nogen keep(matched)
drop coun_aim
rename country_adj coun_aim
drop if coun_aim==""|coun_aim=="中华人民共和国"
rename hs_id HS8
tostring HS8,replace
replace HS8 = "0" + HS8 if length(HS8) == 7
gen HS2007=substr(HS8,1,6) if year==2007
merge n:1 HS2007 using "D:\Project C\HS Conversion\HS2007to1996.dta",nogen update replace
gen HS2002=substr(HS8,1,6) if year<2007 & year>=2002
merge n:1 HS2002 using "D:\Project C\HS Conversion\HS2002to1996.dta",nogen update replace
replace HS1996=substr(HS8,1,6) if year<2002
rename HS1996 HS6
drop if HS6=="" | FRDM=="" | quant_year==0 | value_year==0
gen shipment_type=1 if shipment=="一般贸易" | shipment==""
replace shipment_type=2 if shipment=="进料加工贸易" | shipment=="来料加工贸易" | shipment=="来料加工装配贸易" | shipment=="来料加工装配进口的设备"
replace shipment_type=0 if shipment_type==.
collapse (sum) value_year quant_year, by (FRDM EN exp_imp HS6 coun_aim year shipment_type)
merge n:1 year using "D:\Project C\PWT10.0\US_NER_99_11",nogen keep(matched)
merge n:1 year coun_aim using "D:\Project C\PWT10.0\RER_99_11.dta",nogen keep(matched) keepus(NER RER dlnRER dlnrgdp)
drop if dlnRER==.
gen HS2=substr(HS6,1,2)
sort FRDM HS6 coun_aim year
format EN %30s
format coun_aim %20s
save customs_matched,replace

*-------------------------------------------------------------------------------
* Construct top trade partners
cd "D:\Project C\sample_matched"
use customs_matched,clear
collapse (sum) value_year, by (coun_aim exp_imp)
gen value_exp=value_year if exp_imp=="exp"
gen value_imp=value_year if exp_imp=="imp"
drop value_year
collapse (sum) value_exp value_imp , by (coun_aim)
gsort -value_exp, gen(rank_exp)
gsort -value_imp, gen(rank_imp)
save customs_matched_top_partners,replace

*-------------------------------------------------------------------------------
* Credit constraint measures
* Credit supply measures from Li, Liao, Zhao (2018)
cd "D:\Project C\credit\LLZ_Appendix"
import excel ".\Table14.xlsx", sheet("Sheet1") firstrow clear
label var Pcode "Province code"
label var EFS_all "Ratio of all credit to GDP"
label var EFS_LTL "Ratio of long-term loan to GDP"
save LLZ_Table14,replace

* US financial vulnerability measures from Manova, Wei, Zhang (2015)
cd "D:\Project C\credit\MWZ_Appendix"
import excel ".\MWZ Appendix.xlsx", sheet("Sheet1") firstrow clear
label var ExtFin "Exteral Finance Dependence"
label var Invent "Inventory Ratio"
label var Tang "Asset Tangibility"
label var TrCredit "Trade Credit Intensity"
rename ISIC ISIC2
save MWZ_Appendix,replace

use MWZ_Appendix,clear
keep if ISIC<=1000
tostring ISIC,gen(ISIC2_3d)
save MWZ_Appendix_3d,replace

use MWZ_Appendix,clear
keep if ISIC>1000
tostring ISIC,gen(ISIC2_4d)
gen ISIC2_3d=substr(ISIC2_4d,1,3)
save MWZ_Appendix_4d,replace

cd "D:\Project C\credit"
import delimited ".\LLZ_data\ISIC\ISIC3-ISIC2.csv", stringcols(1 3) clear
drop partial*
rename (isic3 isic2) (ISIC3 ISIC2_4d)
gen ISIC2_3d=substr(ISIC2_4d,1,3)
save ISIC3-ISIC2,replace

use ISIC3-ISIC2,clear
merge n:1 ISIC2_3d using ".\MWZ_Appendix\MWZ_Appendix_3d",nogen
merge n:1 ISIC2_4d using ".\MWZ_Appendix\MWZ_Appendix_4d",nogen update replace
collapse (mean) ExtFin Invent Tang TrCredit, by (ISIC3)
save ISIC3_MWZ,replace

cd "D:\Project C\credit"
use "D:\Project A\deflator\CIC_ADJ-02-03",clear
drop cic02
tostring cic_adj cic03,replace
duplicates drop
save CIC_ADJ-03,replace

cd "D:\Project C\credit"
use ".\LLZ_data\ISIC\ISIC industry code to CIC industry code",clear
rename (IND_CIC IND_ISIC_3) (cic03 ISIC3)
merge n:1 cic03 using CIC_ADJ-03,nogen keep(matched)
drop cic03
save CIC-ISIC3,replace

use CIC-ISIC3,clear
merge n:1 ISIC3 using ISIC3_MWZ,nogen keep(matched)
collapse (mean) ExtFin Invent Tang TrCredit, by (cic_adj)
rename (ExtFin Invent Tang TrCredit) (ExtFin_US Invent_US Tang_US TrCredit_US)
save CIC_MWZ,replace

* China external finance dependence measure from Fan, Lai, Li (2015)
cd "D:\Project C\credit\FLL_Appendix"
import excel "D:\Project C\credit\FLL_Appendix\Table A.1.xlsx", sheet("Sheet1") firstrow clear
tostring CIC,gen(cic2)
label var ExtFin "Exteral Finance Dependence"
save FLL_Appendix_A1,replace

*-------------------------------------------------------------------------------
* Construct new CIE data
* focus on manufacturing firms
cd "D:\Project A\CIE"
use cie1998.dta,clear
keep(FRDM EN year INDTYPE REGTYPE GIOV_CR PERSENG TOIPT SI TWC NAR STOCK FA TA CL TL CWP)
forv i = 1999/2004{
append using cie`i',keep(FRDM EN year INDTYPE REGTYPE GIOV_CR PERSENG TOIPT SI TWC NAR STOCK FA TA CL TL CWP)
}
forv i = 2005/2006{
append using cie`i',keep(FRDM EN year INDTYPE REGTYPE GIOV_CR PERSENG TOIPT SI TWC NAR STOCK FA TA CL TL F334 CWP)
}
rename F334 RND
append using cie2007,keep(FRDM EN year INDTYPE REGTYPE GIOV_CR PERSENG TOIPT SI TWC NAR STOCK FA TA CL TL RND CWP)
bys FRDM: egen EN_adj=mode(EN),maxmode
bys FRDM: egen REGTYPE_adj=mode(REGTYPE),maxmode
drop EN REGTYPE
rename (EN_adj REGTYPE_adj) (EN REGTYPE)
gen year_cic=2 if year<=2002
replace year_cic=3 if year>2002
merge n:1 INDTYPE year_cic using "D:\Project A\deflator\cic_adj",nogen keep(matched)
drop year_cic
destring cic_adj,replace
merge n:1 cic_adj year using "D:\Project A\deflator\input_deflator",nogen keep(matched)
merge n:1 cic_adj year using "D:\Project A\deflator\output_deflator",nogen keep(matched)
merge n:1 year using "D:\Project A\deflator\inv_deflator.dta",nogen keep(matched) keepus(inv_deflator)
*add registration type
gen ownership="SOE" if (REGTYPE=="110" | REGTYPE=="141" | REGTYPE=="143" | REGTYPE=="151"  )
replace ownership="DPE" if (REGTYPE=="120" | REGTYPE=="130" | REGTYPE=="142" | REGTYPE=="149" | REGTYPE=="159" | REGTYPE=="160" | REGTYPE=="170" | REGTYPE=="171" | REGTYPE=="172" | REGTYPE=="173" | REGTYPE=="174" | REGTYPE=="190")
replace ownership="JV" if ( REGTYPE=="210" | REGTYPE=="220" | REGTYPE=="310" | REGTYPE=="320" )
replace ownership="MNE" if ( REGTYPE=="230" | REGTYPE=="240" | REGTYPE=="330" | REGTYPE=="340" )
replace ownership="SOE" if ownership==""
sort FRDM year
format EN %30s
cd "D:\Project C\sample_matched\CIE"
save cie_98_07,replace

*-------------------------------------------------------------------------------
* Markup estimation according to DLW(2012) in DLW.do

*-------------------------------------------------------------------------------
* Add markup and financial vulnerability measures to firm data
cd "D:\Project C\sample_matched\CIE"
use cie_98_07,clear
keep if year>=1999
gen IND2=substr(INDTYPE,1,2)
* Add markup and tfp info
merge 1:1 FRDM year using "D:\Project C\markup\cie_99_07_markup", nogen keepus(Markup_DLWTLD Markup_lag tfp_tld tfp_lag) keep(matched master)
sum Markup_*,detail
winsor2 Markup_*, replace by(year IND2)
sum tfp_*,detail
winsor2 tfp_*, replace by(year IND2)
* Calculate firm-level markup from CIE
sort FRDM year
gen rSI=SI/OutputDefl*100
gen rTOIPT=TOIPT/InputDefl*100
gen rCWP=CWP/InputDefl*100
gen rkap=FA/inv_deflator*100
gen tc=rTOIPT+rCWP+0.15*rkap
gen scratio=rSI/tc
by FRDM: gen scratio_lag=scratio[_n-1] if year==year[_n-1]+1
sum scratio*,detail
winsor2 scratio*, replace cuts(0 99) by(year IND2)
* Calculate firm-level financial constraints from CIE
gen Tang=FA/TA
gen Invent=STOCK/SI
gen RDint=RND/SI
gen Cash=(TWC-NAR-STOCK)/TA
gen Liquid=(TWC-CL)/TA
gen Levg=TA/TL
drop if Tang<0 | Invent<0 | RDint<0 | Cash<0 | Levg<0
tostring cic_adj,replace
gen cic2=substr(cic_adj,1,2)
bys cic2: egen RDint_cic2=mean(RDint)
local varlist "Tang Invent Cash Liquid Levg"
foreach var of local varlist {	
bys cic2: egen `var'_cic2 = median(`var')
}
* Add FLL (2015) measures
merge n:1 cic2 using "D:\Project C\credit\FLL_Appendix\FLL_Appendix_A1",nogen keep(matched) keepus(ExtFin)
rename ExtFin ExtFin_cic2
* Add MWZ (2015) measures
merge n:1 cic_adj using "D:\Project C\credit\CIC_MWZ",nogen keep(matched)
* (PCA) FPC is the first principal component of external finance dependence and asset tangibility
pca Tang_US ExtFin_US
factor Tang_US ExtFin_US,pcf
factortest Tang_US ExtFin_US
rotate, promax(3) factors(1)
predict f1
rename f1 FPC_US
sort FRDM EN year
save cie_credit,replace

*-------------------------------------------------------------------------------
* GVC upstreamness measures (from CMY 2021)
cd "D:\Project C\GVC"
use ups_cmy_hs07_base,clear
collapse (mean) upstreamness [aw=iooutput], by (hs_6)
rename (hs_6 upstreamness) (HS6 ups_HS6)
save ups_cmy_HS6_07,replace

*-------------------------------------------------------------------------------
* Contract intensity measures (from Nunn 2007)
cd "D:\Project C\contract"
use ".\contract_intensity_isic_1997.dta_\contract_intensity_ISIC_1997.dta",clear
rename industry_code ISIC2_3d
keep ISIC2 frac_lib_diff frac_lib_not_homog
save contract_intensity_ISIC_1997,replace

use "D:\Project C\credit\ISIC3-ISIC2",clear
merge n:1 ISIC2_3d using contract_intensity_ISIC_1997,nogen
collapse (mean) frac_lib_diff frac_lib_not_homog, by (ISIC3)
keep if frac_lib_diff!=.
save ISIC3_contract,replace

use "D:\Project C\credit\CIC-ISIC3",clear
merge n:1 ISIC3 using ISIC3_contract,nogen keep(matched)
collapse (mean) frac_lib_diff frac_lib_not_homog, by (cic_adj)
rename (frac_lib_diff frac_lib_not_homog) (rs1 rs2)
label var rs1 "fraction of inputs not sold on exchange and not ref priced"
label var rs2 "fraction of inputs not sold on exchange"
save CIC_contract,replace

*-------------------------------------------------------------------------------
* Trading Partner Base
cd "D:\Project C\sample_matched"
use customs_matched,clear
keep FRDM year exp_imp HS6
duplicates drop
bys FRDM year exp_imp: egen prod_n=count(HS6)
drop HS6
duplicates drop
save customs_matched_product,replace

use customs_matched,clear
keep FRDM year exp_imp coun_aim
duplicates drop
bys FRDM year exp_imp: egen coun_n=count(coun_aim)
drop coun_aim
duplicates drop
save customs_matched_country,replace

use customs_matched,clear
keep FRDM year exp_imp HS6 coun_aim
bys FRDM year exp_imp HS6: egen prod_coun_n=count(coun_aim)
merge n:1 FRDM year exp_imp using customs_matched_product,nogen
merge n:1 FRDM year exp_imp using customs_matched_country,nogen
drop coun_aim
duplicates drop
save customs_matched_product_country,replace

*-------------------------------------------------------------------------------
* Check Two-way traders
cd "D:\Project C\sample_matched"
use customs_matched,clear
keep FRDM year exp_imp
duplicates drop
gen exp=1 if exp_imp=="exp"
replace exp=0 if exp==.
gen imp=1 if exp_imp=="imp"
replace imp=0 if imp==.
collapse (sum) exp imp, by(FRDM year)
gen twoway_trade=1 if exp==1 & imp==1
replace twoway_trade=0 if twoway_trade==.
save customs_twoway_list,replace

*-------------------------------------------------------------------------------
* Merge customs data with CIE data to construct export sample
cd "D:\Project C\sample_matched"
use customs_matched,clear
merge n:1 FRDM year exp_imp HS6 using customs_matched_product_country,nogen
rename prod_coun_n market
keep if exp_imp =="exp"
drop exp_imp
collapse (sum) value_year quant_year, by(FRDM EN year coun_aim NER NER_US RER dlnRER dlnrgdp HS2 HS6 market)
gen price_RMB=value_year*NER_US/quant_year
merge n:1 FRDM year using ".\customs_twoway_list",nogen keep(matched) keepus(twoway_trade)
merge n:1 FRDM year using ".\CIE\cie_credit",nogen keep(matched)
merge n:1 coun_aim using ".\customs_matched_top_partners",nogen keep(matched)
foreach key in 贸易 外贸 经贸 工贸 科贸 商贸 边贸 技贸 进出口 进口 出口 物流 仓储 采购 供应链 货运{
	drop if strmatch(EN, "*`key'*") 
}
bys HS6 coun_aim year: egen MS=pc(value_year),prop
xtile MS_xt4=MS,nq(4)
gen MS_sqr=MS^2
sort FRDM HS6 coun_aim year
by FRDM HS6 coun_aim: gen dlnprice=ln(price_RMB)-ln(price_RMB[_n-1]) if year==year[_n-1]+1
by FRDM HS6 coun_aim: egen year_count=count(year)
drop if year_count<=1
drop if HS2=="93"|HS2=="97"|HS2=="98"|HS2=="99"
egen group_id=group(FRDM HS6 coun_aim)
winsor2 dlnprice, trim by(HS2 year)
local varlist "FPC_US ExtFin_US Invent_US Tang_US ExtFin_cic2 Tang_cic2 Invent_cic2 RDint_cic2 Cash_cic2 Liquid_cic2 Levg_cic2 MS MS_sqr Markup_DLWTLD tfp_tld Markup_lag tfp_lag scratio scratio_lag twoway_trade market"
foreach var of local varlist {
	gen x_`var' = `var'*dlnRER
}
format EN %30s
save sample_matched_exp,replace

*-------------------------------------------------------------------------------
* Baseline regressions for export
cd "D:\Project C\sample_matched"
use sample_matched_exp,clear

eststo exp_baseline: areg dlnprice_tr dlnRER dlnrgdp i.year, a(group_id)
eststo exp_top50: areg dlnprice_tr dlnRER dlnrgdp i.year if rank_exp<=50, a(group_id)
eststo exp_top20: areg dlnprice_tr dlnRER dlnrgdp i.year if rank_exp<=20, a(group_id)

estfe exp_baseline exp_top50 exp_top20, labels(group_id "Firm-product-country FE")
esttab exp_baseline exp_top50 exp_top20 using "D:\Project C\tables\matched\table_exp_baseline.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Baseline" "Top 50" "Top 20")

*-------------------------------------------------------------------------------
* Regressions with financial constraints for export
cd "D:\Project C\sample_matched"
use sample_matched_exp,clear

eststo exp_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year, a(group_id)
eststo exp_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year, a(group_id)
eststo exp_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year, a(group_id)
eststo exp_Invent_US: areg dlnprice_tr dlnRER x_Invent_US dlnrgdp i.year, a(group_id)

estfe exp_FPC_US exp_ExtFin_US exp_Tang_US exp_Invent_US, labels(group_id "Firm-product-country FE")
esttab exp_FPC_US exp_ExtFin_US exp_Tang_US exp_Invent_US using "D:\Project C\tables\matched\table_exp_fin_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("FPC" "External Finance" "Tangibility" "Inventory") order(dlnRER dlnrgdp x_*)

eststo exp_ExtFin_cic2: areg dlnprice_tr dlnRER x_ExtFin_cic2 dlnrgdp i.year, a(group_id)
eststo exp_Tang_cic2: areg dlnprice_tr dlnRER x_Tang_cic2 dlnrgdp i.year, a(group_id)
eststo exp_Invent_cic2: areg dlnprice_tr dlnRER x_Invent_cic2 dlnrgdp i.year, a(group_id)
eststo exp_RDint_cic2: areg dlnprice_tr dlnRER x_RDint_cic2 dlnrgdp i.year, a(group_id)

estfe exp_ExtFin_cic2 exp_Tang_cic2 exp_Invent_cic2 exp_RDint_cic2, labels(group_id "Firm-product-country FE")
esttab exp_ExtFin_cic2 exp_Tang_cic2 exp_Invent_cic2 exp_RDint_cic2 using "D:\Project C\tables\matched\table_exp_fin_CN.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("External Finance" "Tangibility" "Inventory" "R&D Intensity") order(dlnRER dlnrgdp x_*)

*-------------------------------------------------------------------------------
* Regressions with market share
cd "D:\Project C\sample_matched"
use sample_matched_exp,clear

eststo exp_MS: areg dlnprice_tr dlnRER x_MS dlnrgdp MS i.year, a(group_id)
eststo exp_MS_sqr: areg dlnprice_tr dlnRER x_MS x_MS_sqr dlnrgdp MS i.year, a(group_id)
eststo exp_MS_sqr_FPC_US: areg dlnprice_tr dlnRER x_MS x_MS_sqr x_FPC_US dlnrgdp MS i.year, a(group_id)
eststo exp_MS_sqr_ExtFin_US: areg dlnprice_tr dlnRER x_MS x_MS_sqr x_ExtFin_US dlnrgdp MS i.year, a(group_id)
eststo exp_MS_sqr_Tang_US: areg dlnprice_tr dlnRER x_MS x_MS_sqr x_Tang_US dlnrgdp MS i.year, a(group_id)

estfe exp_MS exp_MS_sqr exp_MS_sqr_FPC_US exp_MS_sqr_ExtFin_US exp_MS_sqr_Tang_US, labels(group_id "Firm-product-country FE")
esttab exp_MS exp_MS_sqr exp_MS_sqr_FPC_US exp_MS_sqr_ExtFin_US exp_MS_sqr_Tang_US using "D:\Project C\tables\matched\table_exp_MS.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("MS" "MS^2" "Add FPC" "Add ExtFin" "Add Tangibility") order(dlnRER dlnrgdp x_*)

forv i=1/4{
	eststo exp_MS4_`i': areg dlnprice_tr dlnRER dlnrgdp i.year if MS_xt4==`i', a(group_id)
	
}
estfe exp_MS4_*, labels(group_id "Firm-product-country FE")
esttab exp_MS4_* using "D:\Project C\tables\matched\table_exp_MS_xt4.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles( "1st" "2nd" "3rd" "4th")

forv i=1/4{
	eststo exp_MS4_`i'_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year if MS_xt4==`i', a(group_id)
	eststo exp_MS4_`i'_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year if MS_xt4==`i', a(group_id)
}
estfe exp_MS4_1_* exp_MS4_2_* exp_MS4_3_* exp_MS4_4_*, labels(group_id "Firm-product-country FE")
esttab exp_MS4_1* exp_MS4_2* exp_MS4_3* exp_MS4_4* using "D:\Project C\tables\matched\table_exp_MS_xt4_fin_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles( "1st" "1st" "2nd" "2nd" "3rd" "3rd" "4th" "4th") order(dlnRER dlnrgdp x_*)

*-------------------------------------------------------------------------------
* Regressions controlling firms' markup and TFP
cd "D:\Project C\sample_matched"
use sample_matched_exp,clear

eststo exp_markup: areg dlnprice_tr dlnRER x_Markup_lag dlnrgdp Markup_lag i.year, a(group_id)
eststo exp_FPC_US_markup: areg dlnprice_tr dlnRER x_FPC_US x_Markup_lag dlnrgdp Markup_lag i.year, a(group_id)
eststo exp_ExtFin_US_markup: areg dlnprice_tr dlnRER x_ExtFin_US x_Markup_lag dlnrgdp Markup_lag i.year, a(group_id)
eststo exp_Tang_US_markup: areg dlnprice_tr dlnRER x_Tang_US x_Markup_lag Markup_lag dlnrgdp i.year, a(group_id)
eststo exp_Invent_US_markup: areg dlnprice_tr dlnRER x_Invent_US x_Markup_lag Markup_lag dlnrgdp i.year, a(group_id)

estfe exp_markup exp_FPC_US_markup exp_ExtFin_US_markup exp_Tang_US_markup exp_Invent_US_markup, labels(group_id "Firm-product-country FE")
esttab exp_markup exp_FPC_US_markup exp_ExtFin_US_markup exp_Tang_US_markup exp_Invent_US_markup using "D:\Project C\tables\matched\table_exp_markup_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp x_*_lag x_*_US)

eststo exp_tfp: areg dlnprice_tr dlnRER x_tfp_lag dlnrgdp tfp_lag i.year, a(group_id)
eststo exp_ExtFin_US_tfp: areg dlnprice_tr dlnRER x_ExtFin_US x_tfp_lag dlnrgdp tfp_lag i.year, a(group_id)
eststo exp_Tang_US_tfp: areg dlnprice_tr dlnRER x_Tang_US x_tfp_lag dlnrgdp tfp_lag i.year, a(group_id)

eststo exp_scratio: areg dlnprice_tr dlnRER x_scratio_lag dlnrgdp scratio_lag i.year, a(group_id)
eststo exp_ExtFin_US_scratio: areg dlnprice_tr dlnRER x_ExtFin_US x_scratio_lag dlnrgdp scratio_lag i.year, a(group_id)
eststo exp_Tang_US_scratio: areg dlnprice_tr dlnRER x_Tang_US x_scratio_lag dlnrgdp scratio_lag i.year, a(group_id)

estfe exp_markup exp_ExtFin_US_markup exp_Tang_US_markup exp_tfp exp_ExtFin_US_tfp exp_Tang_US_tfp exp_scratio exp_ExtFin_US_scratio exp_Tang_US_scratio, labels(group_id "Firm-product-country FE")
esttab exp_markup exp_ExtFin_US_markup exp_Tang_US_markup exp_tfp exp_ExtFin_US_tfp exp_Tang_US_tfp exp_scratio exp_ExtFin_US_scratio exp_Tang_US_scratio using "D:\Project C\tables\matched\table_exp_markup_tfp_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp x_*_lag x_*_US)

*-------------------------------------------------------------------------------
* Two-way traders
cd "D:\Project C\sample_matched"
use sample_matched_exp,clear

eststo exp_twoway: areg dlnprice_tr dlnRER dlnrgdp i.year if twoway_trade==1, a(group_id)
eststo exp_twoway_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year if twoway_trade==1, a(group_id)
eststo exp_twoway_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year if twoway_trade==1, a(group_id)
eststo exp_twoway_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year if twoway_trade==1, a(group_id)
eststo exp_oneway: areg dlnprice_tr dlnRER dlnrgdp i.year if twoway_trade==0, a(group_id)
eststo exp_oneway_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year if twoway_trade==0, a(group_id)
eststo exp_oneway_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year if twoway_trade==0, a(group_id)
eststo exp_oneway_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year if twoway_trade==0, a(group_id)

estfe exp_twoway exp_twoway_FPC_US exp_twoway_ExtFin_US exp_twoway_Tang_US exp_oneway exp_oneway_FPC_US exp_oneway_ExtFin_US exp_oneway_Tang_US, labels(group_id "Firm-product-country FE")
esttab exp_twoway exp_twoway_FPC_US exp_twoway_ExtFin_US exp_twoway_Tang_US exp_oneway exp_oneway_FPC_US exp_oneway_ExtFin_US exp_oneway_Tang_US using "D:\Project C\tables\matched\table_exp_twoway_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Twoway" "FPC" "External Finance" "Tangibility" "Oneway" "FPC" "External Finance" "Tangibility") order(dlnRER dlnrgdp x_*_US)

*-------------------------------------------------------------------------------
* Export Markets
cd "D:\Project C\sample_matched"
use sample_matched_exp,clear

eststo exp_market: areg dlnprice_tr dlnRER x_market dlnrgdp i.year, a(group_id)

gen x_FPC_US_market=x_FPC_US*market
gen x_ExtFin_US_market=x_ExtFin_US*market
gen x_Tang_US_market=x_Tang_US*market
gen x_Invent_US_market=x_Invent_US*market

eststo exp_FPC_US_market: areg dlnprice_tr dlnRER x_market x_FPC_US_market x_FPC_US dlnrgdp i.year, a(group_id)
eststo exp_ExtFin_US_market: areg dlnprice_tr dlnRER x_market x_ExtFin_US_market x_ExtFin_US dlnrgdp i.year, a(group_id)
eststo exp_Tang_US_market: areg dlnprice_tr dlnRER x_market x_Tang_US_market x_Tang_US dlnrgdp i.year, a(group_id)
eststo exp_Invent_US_market: areg dlnprice_tr dlnRER x_market x_Invent_US_market x_Invent_US dlnrgdp i.year, a(group_id)

estfe exp_market exp_FPC_US_market exp_ExtFin_US_market exp_Tang_US_market exp_Invent_US_market, labels(group_id "Firm-product-country FE")
esttab exp_market exp_FPC_US_market exp_ExtFin_US_market exp_Tang_US_market exp_Invent_US_market using "D:\Project C\tables\matched\table_exp_market.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp x_*)

*-------------------------------------------------------------------------------
* Alternative FEs
cd "D:\Project C\sample_matched"
use sample_matched_exp,clear

egen group_id_fy=group(FRDM year)
egen group_id_pc=group(HS6 coun_aim)

eststo exp_FPC_US_fe1: reghdfe dlnprice_tr dlnRER x_FPC_US dlnrgdp, absorb(group_id_fy coun_aim HS6)
eststo exp_ExtFin_US_fe1: reghdfe dlnprice_tr dlnRER x_ExtFin_US dlnrgdp, absorb(group_id_fy coun_aim HS6)
eststo exp_Tang_US_fe1: reghdfe dlnprice_tr dlnRER x_Tang_US dlnrgdp, absorb(group_id_fy coun_aim HS6)
eststo exp_Invent_US_fe1: reghdfe dlnprice_tr dlnRER x_Invent_US dlnrgdp, absorb(group_id_fy coun_aim HS6)

eststo exp_FPC_US_fe2: reghdfe dlnprice_tr dlnRER x_FPC_US dlnrgdp, absorb(group_id_fy group_id_pc)
eststo exp_ExtFin_US_fe2: reghdfe dlnprice_tr dlnRER x_ExtFin_US dlnrgdp, absorb(group_id_fy group_id_pc)
eststo exp_Tang_US_fe2: reghdfe dlnprice_tr dlnRER x_Tang_US dlnrgdp, absorb(group_id_fy group_id_pc)
eststo exp_Invent_US_fe2: reghdfe dlnprice_tr dlnRER x_Invent_US dlnrgdp, absorb(group_id_fy group_id_pc)

estfe exp_FPC_US_fe1 exp_ExtFin_US_fe1 exp_Tang_US_fe1 exp_Invent_US_fe1 exp_FPC_US_fe2 exp_ExtFin_US_fe2 exp_Tang_US_fe2 exp_Invent_US_fe2, labels(group_id "Firm-product-country FE" group_id_fy "Firm-year FE" group_id_pc "Product-Country FE" coun_aim "Country FE" HS6 "Product FE")
esttab exp_FPC_US_fe1 exp_ExtFin_US_fe1 exp_Tang_US_fe1 exp_Invent_US_fe1 exp_FPC_US_fe2 exp_ExtFin_US_fe2 exp_Tang_US_fe2 exp_Invent_US_fe2 using "D:\Project C\tables\matched\table_exp_fe.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate(`r(indicate_fe)') mtitles("FPC" "External Finance" "Tangibility" "Inventory" "FPC" "External Finance" "Tangibility" "Inventory") order(dlnRER dlnrgdp x_*)

*-------------------------------------------------------------------------------
* Ordinary vs Processing
cd "D:\Project C\sample_matched"
use sample_matched_exp,clear

eststo exp_ordinary_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year if shipment_type==1, a(group_id)
eststo exp_ordinary_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year if shipment_type==1, a(group_id)
eststo exp_ordinary_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year if shipment_type==1, a(group_id)
eststo exp_ordinary_Invent_US: areg dlnprice_tr dlnRER x_Invent_US dlnrgdp i.year if shipment_type==1, a(group_id)

eststo exp_process_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year if shipment_type==2, a(group_id)
eststo exp_process_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year if shipment_type==2, a(group_id)
eststo exp_process_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year if shipment_type==2, a(group_id)
eststo exp_process_Invent_US: areg dlnprice_tr dlnRER x_Invent_US dlnrgdp i.year if shipment_type==2, a(group_id)

estfe exp_ordinary_FPC_US exp_ordinary_ExtFin_US exp_ordinary_Tang_US exp_ordinary_Invent_US exp_process_FPC_US exp_process_ExtFin_US exp_process_Tang_US exp_process_Invent_US, labels(group_id "Firm-product-country FE")

esttab exp_ordinary_FPC_US exp_ordinary_ExtFin_US exp_ordinary_Tang_US exp_ordinary_Invent_US exp_process_FPC_US exp_process_ExtFin_US exp_process_Tang_US exp_process_Invent_US using "D:\Project C\tables\matched\table_exp_process.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Ordinary" "Ordinary" "Ordinary" "Ordinary" "Processing" "Processing" "Processing" "Processing") order(dlnRER dlnrgdp x_*)

*-------------------------------------------------------------------------------
* Use the same method to construct import sample
cd "D:\Project C\sample_matched"
use customs_matched,clear
merge n:1 FRDM year exp_imp HS6 using customs_matched_product_country,nogen
rename prod_coun_n source
keep if exp_imp =="imp"
drop exp_imp
collapse (sum) value_year quant_year, by(FRDM EN year coun_aim NER NER_US RER dlnRER dlnrgdp HS2 HS6 source)
gen price_RMB=value_year*NER_US/quant_year
merge n:1 FRDM year using ".\customs_twoway_list",nogen keep(matched) keepus(twoway_trade)
merge n:1 FRDM year using ".\CIE\cie_credit",nogen keep(matched)
merge n:1 coun_aim using ".\customs_matched_top_partners",nogen keep(matched)
foreach key in 贸易 外贸 经贸 工贸 科贸 商贸 边贸 技贸 进出口 进口 出口 物流 仓储 采购 供应链 货运{
	drop if strmatch(EN, "*`key'*") 
}
bys HS6 coun_aim year: egen MS=pc(value_year),prop
xtile MS_xt4=MS,nq(4)
gen MS_sqr=MS^2
sort FRDM HS6 coun_aim year
by FRDM HS6 coun_aim: gen dlnprice=ln(price_RMB)-ln(price_RMB[_n-1]) if year==year[_n-1]+1
by FRDM HS6 coun_aim: egen year_count=count(year)
drop if year_count<=1
drop if HS2=="93"|HS2=="97"|HS2=="98"|HS2=="99"
egen group_id=group(FRDM HS6 coun_aim)
winsor2 dlnprice, trim by(HS2 year)
local varlist "FPC_US ExtFin_US Invent_US Tang_US ExtFin_cic2 Tang_cic2 Invent_cic2 RDint_cic2 Cash_cic2 Liquid_cic2 Levg_cic2 MS MS_sqr Markup_DLWTLD tfp_tld Markup_lag tfp_lag scratio scratio_lag twoway_trade source"
foreach var of local varlist {
	gen x_`var' = `var'*dlnRER
}
format EN %30s
save sample_matched_imp,replace

*-------------------------------------------------------------------------------
* Baseline regressions for import
cd "D:\Project C\sample_matched"
use sample_matched_imp,clear

eststo imp_baseline: areg dlnprice_tr dlnRER dlnrgdp i.year, a(group_id)
eststo imp_top50: areg dlnprice_tr dlnRER dlnrgdp i.year if rank_imp<=50, a(group_id)
eststo imp_top20: areg dlnprice_tr dlnRER dlnrgdp i.year if rank_imp<=20, a(group_id)

estfe imp_baseline imp_top50 imp_top20, labels(group_id "Firm-product-country FE")
esttab imp_baseline imp_top50 imp_top20 using "D:\Project C\tables\matched\table_imp_baseline.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Baseline" "Top 50" "Top 20")

*-------------------------------------------------------------------------------
* Regressions with financial constraints for import
cd "D:\Project C\sample_matched"
use sample_matched_imp,clear

eststo imp_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year, a(group_id)
eststo imp_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year, a(group_id)
eststo imp_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year, a(group_id)
eststo imp_Invent_US: areg dlnprice_tr dlnRER x_Invent_US dlnrgdp i.year, a(group_id)

estfe imp_FPC_US imp_ExtFin_US imp_Tang_US imp_Invent_US, labels(group_id "Firm-product-country FE")
esttab imp_FPC_US imp_ExtFin_US imp_Tang_US imp_Invent_US using "D:\Project C\tables\matched\table_imp_fin_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("FPC" "External Finance" "Tangibility" "Inventory") order(dlnRER dlnrgdp x_*)

eststo imp_ExtFin_cic2: areg dlnprice_tr dlnRER x_ExtFin_cic2 dlnrgdp i.year, a(group_id)
eststo imp_Tang_cic2: areg dlnprice_tr dlnRER x_Tang_cic2 dlnrgdp i.year, a(group_id)
eststo imp_Invent_cic2: areg dlnprice_tr dlnRER x_Invent_cic2 dlnrgdp i.year, a(group_id)
eststo imp_RDint_cic2: areg dlnprice_tr dlnRER x_RDint_cic2 dlnrgdp i.year, a(group_id)

estfe imp_ExtFin_cic2 imp_Tang_cic2 imp_Invent_cic2 imp_RDint_cic2, labels(group_id "Firm-product-country FE")
esttab imp_ExtFin_cic2 imp_Tang_cic2 imp_Invent_cic2 imp_RDint_cic2 using "D:\Project C\tables\matched\table_imp_fin_CN.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles( "External Finance" "Tangibility" "Inventory" "R&D Intensity") order(dlnRER dlnrgdp x_*)

*-------------------------------------------------------------------------------
* Regressions with market share
cd "D:\Project C\sample_matched"
use sample_matched_imp,clear

eststo imp_MS: areg dlnprice_tr dlnRER x_MS dlnrgdp MS i.year, a(group_id)
eststo imp_MS_sqr: areg dlnprice_tr dlnRER x_MS x_MS_sqr dlnrgdp MS i.year, a(group_id)
eststo imp_MS_sqr_FPC_US: areg dlnprice_tr dlnRER x_MS x_MS_sqr x_FPC_US dlnrgdp MS i.year, a(group_id)
eststo imp_MS_sqr_ExtFin_US: areg dlnprice_tr dlnRER x_MS x_MS_sqr x_ExtFin_US dlnrgdp MS i.year, a(group_id)
eststo imp_MS_sqr_Tang_US: areg dlnprice_tr dlnRER x_MS x_MS_sqr x_Tang_US dlnrgdp MS i.year, a(group_id)

estfe imp_MS imp_MS_sqr imp_MS_sqr_FPC_US imp_MS_sqr_ExtFin_US imp_MS_sqr_Tang_US, labels(group_id "Firm-product-country FE")
esttab imp_MS imp_MS_sqr imp_MS_sqr_FPC_US imp_MS_sqr_ExtFin_US imp_MS_sqr_Tang_US using "D:\Project C\tables\matched\table_imp_MS.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("MS" "MS^2" "Add FPC" "Add ExtFin" "Add Tangibility") order(dlnRER dlnrgdp x_*)

forv i=1/4{
	eststo imp_MS4_`i': areg dlnprice_tr dlnRER dlnrgdp i.year if MS_xt4==`i', a(group_id)	
}
estfe imp_MS4_1 imp_MS4_2 imp_MS4_3 imp_MS4_4, labels(group_id "Firm-product-country FE")
esttab imp_MS4_1 imp_MS4_2 imp_MS4_3 imp_MS4_4 using "D:\Project C\tables\matched\table_imp_MS_xt4.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles( "1st" "2nd" "3rd" "4th")

forv i=1/4{
	eststo imp_MS4_`i'_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year if MS_xt4==`i', a(group_id)
	eststo imp_MS4_`i'_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year if MS_xt4==`i', a(group_id)
}
estfe imp_MS4_1_* imp_MS4_2_* imp_MS4_3_* imp_MS4_4_*, labels(group_id "Firm-product-country FE")
esttab imp_MS4_1* imp_MS4_2* imp_MS4_3* imp_MS4_4* using "D:\Project C\tables\matched\table_imp_MS_xt4_fin_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles( "1st" "1st" "2nd" "2nd" "3rd" "3rd" "4th" "4th") order(dlnRER dlnrgdp x_*)

*-------------------------------------------------------------------------------
* Regressions controlling firms' markup and TFP
cd "D:\Project C\sample_matched"
use sample_matched_imp,clear

eststo imp_markup: areg dlnprice_tr dlnRER x_Markup_lag dlnrgdp Markup_lag i.year, a(group_id)
eststo imp_FPC_US_markup: areg dlnprice_tr dlnRER x_FPC_US x_Markup_lag dlnrgdp Markup_lag i.year, a(group_id)
eststo imp_ExtFin_US_markup: areg dlnprice_tr dlnRER x_ExtFin_US x_Markup_lag dlnrgdp Markup_lag i.year, a(group_id)
eststo imp_Tang_US_markup: areg dlnprice_tr dlnRER x_Tang_US x_Markup_lag Markup_lag dlnrgdp i.year, a(group_id)
eststo imp_Invent_US_markup: areg dlnprice_tr dlnRER x_Invent_US x_Markup_lag Markup_lag dlnrgdp i.year, a(group_id)

estfe imp_markup imp_FPC_US_markup imp_ExtFin_US_markup imp_Tang_US_markup imp_Invent_US_markup, labels(group_id "Firm-product-country FE")
esttab imp_markup imp_FPC_US_markup imp_ExtFin_US_markup imp_Tang_US_markup imp_Invent_US_markup using "D:\Project C\tables\matched\table_imp_markup_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp x_*_lag x_*_US)

eststo imp_tfp: areg dlnprice_tr dlnRER x_tfp_lag dlnrgdp tfp_lag i.year, a(group_id)
eststo imp_ExtFin_US_tfp: areg dlnprice_tr dlnRER x_ExtFin_US x_tfp_lag dlnrgdp tfp_lag i.year, a(group_id)
eststo imp_Tang_US_tfp: areg dlnprice_tr dlnRER x_Tang_US x_tfp_lag dlnrgdp tfp_lag i.year, a(group_id)

eststo imp_scratio: areg dlnprice_tr dlnRER x_scratio_lag dlnrgdp scratio_lag i.year, a(group_id)
eststo imp_ExtFin_US_scratio: areg dlnprice_tr dlnRER x_ExtFin_US x_scratio_lag dlnrgdp scratio_lag i.year, a(group_id)
eststo imp_Tang_US_scratio: areg dlnprice_tr dlnRER x_Tang_US x_scratio_lag dlnrgdp scratio_lag i.year, a(group_id)

estfe imp_markup imp_ExtFin_US_markup imp_Tang_US_markup imp_tfp imp_ExtFin_US_tfp imp_Tang_US_tfp imp_scratio imp_ExtFin_US_scratio imp_Tang_US_scratio, labels(group_id "Firm-product-country FE")
esttab imp_markup imp_ExtFin_US_markup imp_Tang_US_markup imp_tfp imp_ExtFin_US_tfp imp_Tang_US_tfp imp_scratio imp_ExtFin_US_scratio imp_Tang_US_scratio using "D:\Project C\tables\matched\table_imp_markup_tfp_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp x_*_lag x_*_US)

*-------------------------------------------------------------------------------
* Two-way traders
cd "D:\Project C\sample_matched"
use sample_matched_imp,clear

eststo imp_twoway: areg dlnprice_tr dlnRER dlnrgdp i.year if twoway_trade==1, a(group_id)
eststo imp_twoway_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year if twoway_trade==1, a(group_id)
eststo imp_twoway_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year if twoway_trade==1, a(group_id)
eststo imp_twoway_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year if twoway_trade==1, a(group_id)
eststo imp_oneway: areg dlnprice_tr dlnRER dlnrgdp i.year if twoway_trade==0, a(group_id)
eststo imp_oneway_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year if twoway_trade==0, a(group_id)
eststo imp_oneway_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year if twoway_trade==0, a(group_id)
eststo imp_oneway_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year if twoway_trade==0, a(group_id)

estfe imp_twoway imp_twoway_FPC_US imp_twoway_ExtFin_US imp_twoway_Tang_US imp_oneway imp_oneway_FPC_US imp_oneway_ExtFin_US imp_oneway_Tang_US, labels(group_id "Firm-product-country FE")
esttab imp_twoway imp_twoway_FPC_US imp_twoway_ExtFin_US imp_twoway_Tang_US imp_oneway imp_oneway_FPC_US imp_oneway_ExtFin_US imp_oneway_Tang_US using "D:\Project C\tables\matched\table_imp_twoway_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Twoway" "FPC" "External Finance" "Tangibility" "Oneway" "FPC" "External Finance" "Tangibility") order(dlnRER dlnrgdp x_*_US)

gen x_ExtFin_US_twoway=x_ExtFin_US*twoway_trade
gen x_Tang_US_twoway=x_Tang_US*twoway_trade
areg dlnprice_tr dlnRER x_twoway_trade dlnrgdp twoway_trade i.year, a(group_id)
areg dlnprice_tr dlnRER x_twoway_trade x_ExtFin_US x_ExtFin_US_twoway dlnrgdp i.year, a(group_id)
areg dlnprice_tr dlnRER x_twoway_trade x_Tang_US x_Tang_US_twoway dlnrgdp i.year, a(group_id)

*-------------------------------------------------------------------------------
* Import Sources
cd "D:\Project C\sample_matched"
use sample_matched_imp,clear

eststo imp_source: areg dlnprice_tr dlnRER x_source dlnrgdp i.year, a(group_id)

gen x_FPC_US_source=x_FPC_US*source
gen x_ExtFin_US_source=x_ExtFin_US*source
gen x_Tang_US_source=x_Tang_US*source
gen x_Invent_US_source=x_Invent_US*source

eststo imp_FPC_US_source: areg dlnprice_tr dlnRER x_source x_FPC_US_source x_FPC_US dlnrgdp i.year, a(group_id)
eststo imp_ExtFin_US_source: areg dlnprice_tr dlnRER x_source x_ExtFin_US_source x_ExtFin_US dlnrgdp i.year, a(group_id)
eststo imp_Tang_US_source: areg dlnprice_tr dlnRER x_source x_Tang_US_source x_Tang_US dlnrgdp i.year, a(group_id)
eststo imp_Invent_US_source: areg dlnprice_tr dlnRER x_source x_Invent_US_source x_Invent_US dlnrgdp i.year, a(group_id)

estfe imp_source imp_FPC_US_source imp_ExtFin_US_source imp_Tang_US_source imp_Invent_US_source, labels(group_id "Firm-product-country FE")
esttab imp_source imp_FPC_US_source imp_ExtFin_US_source imp_Tang_US_source imp_Invent_US_source using "D:\Project C\tables\matched\table_imp_source.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp x_*)

*-------------------------------------------------------------------------------
* Alternative FEs
cd "D:\Project C\sample_matched"
use sample_matched_imp,clear

egen group_id_fy=group(FRDM year)
egen group_id_pc=group(HS6 coun_aim)

eststo imp_FPC_US_fe1: reghdfe dlnprice_tr dlnRER x_FPC_US dlnrgdp, absorb(group_id_fy coun_aim HS6)
eststo imp_ExtFin_US_fe1: reghdfe dlnprice_tr dlnRER x_ExtFin_US dlnrgdp, absorb(group_id_fy coun_aim HS6)
eststo imp_Tang_US_fe1: reghdfe dlnprice_tr dlnRER x_Tang_US dlnrgdp, absorb(group_id_fy coun_aim HS6)
eststo imp_Invent_US_fe1: reghdfe dlnprice_tr dlnRER x_Invent_US dlnrgdp, absorb(group_id_fy coun_aim HS6)

eststo imp_FPC_US_fe2: reghdfe dlnprice_tr dlnRER x_FPC_US dlnrgdp, absorb(group_id_fy group_id_pc)
eststo imp_ExtFin_US_fe2: reghdfe dlnprice_tr dlnRER x_ExtFin_US dlnrgdp, absorb(group_id_fy group_id_pc)
eststo imp_Tang_US_fe2: reghdfe dlnprice_tr dlnRER x_Tang_US dlnrgdp, absorb(group_id_fy group_id_pc)
eststo imp_Invent_US_fe2: reghdfe dlnprice_tr dlnRER x_Invent_US dlnrgdp, absorb(group_id_fy group_id_pc)

estfe imp_FPC_US_fe1 imp_ExtFin_US_fe1 imp_Tang_US_fe1 imp_Invent_US_fe1 imp_FPC_US_fe2 imp_ExtFin_US_fe2 imp_Tang_US_fe2 imp_Invent_US_fe2, labels(group_id "Firm-product-country FE" group_id_fy "Firm-year FE" group_id_pc "Product-Country FE" coun_aim "Country FE" HS6 "Product FE")
esttab imp_FPC_US_fe1 imp_ExtFin_US_fe1 imp_Tang_US_fe1 imp_Invent_US_fe1 imp_FPC_US_fe2 imp_ExtFin_US_fe2 imp_Tang_US_fe2 imp_Invent_US_fe2 using "D:\Project C\tables\matched\table_imp_fe.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate(`r(indicate_fe)') mtitles("FPC" "External Finance" "Tangibility" "Inventory" "FPC" "External Finance" "Tangibility" "Inventory") order(dlnRER dlnrgdp x_*)

*-------------------------------------------------------------------------------
* Ordinary vs Processing
cd "D:\Project C\sample_matched"
use sample_matched_imp,clear

eststo imp_ordinary_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year if shipment_type==1, a(group_id)
eststo imp_ordinary_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year if shipment_type==1, a(group_id)
eststo imp_ordinary_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year if shipment_type==1, a(group_id)
eststo imp_ordinary_Invent_US: areg dlnprice_tr dlnRER x_Invent_US dlnrgdp i.year if shipment_type==1, a(group_id)

eststo imp_process_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year if shipment_type==2, a(group_id)
eststo imp_process_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year if shipment_type==2, a(group_id)
eststo imp_process_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year if shipment_type==2, a(group_id)
eststo imp_process_Invent_US: areg dlnprice_tr dlnRER x_Invent_US dlnrgdp i.year if shipment_type==2, a(group_id)

estfe imp_ordinary_FPC_US imp_ordinary_ExtFin_US imp_ordinary_Tang_US imp_ordinary_Invent_US imp_process_FPC_US imp_process_ExtFin_US imp_process_Tang_US imp_process_Invent_US, labels(group_id "Firm-product-country FE")

esttab imp_ordinary_FPC_US imp_ordinary_ExtFin_US imp_ordinary_Tang_US imp_ordinary_Invent_US imp_process_FPC_US imp_process_ExtFin_US imp_process_Tang_US imp_process_Invent_US using "D:\Project C\tables\matched\table_imp_process.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Ordinary" "Ordinary" "Ordinary" "Ordinary" "Processing" "Processing" "Processing" "Processing") order(dlnRER dlnrgdp x_*)