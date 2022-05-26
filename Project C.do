set processors 16
dis c(processors)

*-------------------------------------------------------------------------------
* Use aggregate index data
cd "D:\Project C\aggregate index"
import excel ".\CN EER Index.xlsx", sheet("Sheet1") firstrow clear
save CN_EER_index,replace
use "D:\Project A\PWT10.0\pwt100.dta", clear
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
gen period=1 if year<=2000
replace period=2 if year>2000 & year<=2011
replace period=3 if year>2011
bys period:reg dlnprice_exp dlnREER dlnpcost dlnrgdp

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
* Construct export sample

cd "D:\Project C\sample_all"
use customs_all,clear
keep if exp_imp =="exp"
drop exp_imp
merge n:1 year using "D:\Project A\PWT10.0\US_NER_99_11",nogen keep(matched)
gen price_RMB=value*NER_US/quant
merge n:1 year coun_aim using "D:\Project A\PWT10.0\RER_99_11.dta",nogen keep(matched) keepus(NER RER dlnRER dlnrgdp)
sort party_id HS6 coun_aim year
by party_id HS6 coun_aim: gen dlnprice=ln(price_RMB)-ln(price_RMB[_n-1]) if year==year[_n-1]+1
gen HS2=substr(HS6,1,2)
save customs_all_exp,replace

cd "D:\Project C\sample_all"
use customs_all_exp,replace
collapse (sum) value quant, by (coun_aim)
gsort -value
gen partner=0
replace partner=1 if value>10000000000
replace partner=2 if value>100000000000
save top_exp_country,replace

cd "D:\Project C\sample_all"
use customs_all_exp,replace
foreach key in 贸易 外贸 经贸 工贸 科贸 商贸 边贸 技贸 进出口 进口 出口 物流 仓储 采购 供应链 货运{
	drop if strmatch(EN, "*`key'*") 
}
merge n:1 coun_aim using "D:\Project C\top_exp_country",nogen keep(matched) keepus(coun_aim partner)
sort party_id HS6 coun_aim year
by party_id HS6 coun_aim: egen year_count=count(year)
drop if year_count<=1
drop if HS2=="93"|HS2=="97"|HS2=="98"|HS2=="99"
winsor2 dlnprice, trim by(HS2 year)
egen group_id=group(party_id HS6 coun_aim)
gen period=1 if year<=2004
replace period=2 if year>2004 & year<=2008
replace period=3 if year>2008
save sample_all_exp,replace

cd "D:\Project C\sample_all"
use sample_all_exp,clear
eststo reg_all: qui areg dlnprice_tr dlnRER dlnrgdp i.year, a(group_id)
eststo reg_all_top: qui areg dlnprice_tr dlnRER dlnrgdp i.year if partner==2, a(group_id)
forv i=2003/2009{
	eststo reg_all_`i': areg dlnprice_tr dlnRER dlnrgdp i.year if year>=`i'-2 & year<=`i'+2, a(group_id)
}
estfe reg_all reg_all_top reg_all_20*, labels(group_id "Firm-product-country FE")
esttab reg_all reg_all_top reg_all_20* using ".\tables\table_reg_all.csv", replace b(3) se(3) ///
starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') ///
mtitles("Baseline" "Top Destinations" "03" "04" "05" "06" "07" "08" "09")

*-------------------------------------------------------------------------------
* Construct export sample

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
collapse (sum) value_year quant_year, by (FRDM EN exp_imp hs_id coun_aim year)
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
collapse (sum) value_year quant_year, by (FRDM EN exp_imp HS6 coun_aim year)
merge n:1 year using "D:\Project C\PWT10.0\US_NER_99_11",nogen keep(matched)
gen price_RMB=value_year*NER_US/quant_year
merge n:1 year coun_aim using "D:\Project C\PWT10.0\RER_99_11.dta",nogen keep(matched) keepus(NER RER dlnRER dlnrgdp)
drop if dlnRER==.
gen HS2=substr(HS6,1,2)
gen HS4=substr(HS6,1,4)
sort FRDM HS6 coun_aim year
format EN %30s
format coun_aim %20s
save customs_matched,replace

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
keep(FRDM EN year INDTYPE REGTYPE GIOV_CR PERSENG TOIPT SI TWC NAR STOCK FA TA CL TL)
forv i = 1999/2004{
append using cie`i',keep(FRDM EN year INDTYPE REGTYPE GIOV_CR PERSENG TOIPT SI TWC NAR STOCK FA TA CL TL)
}
forv i = 2005/2006{
append using cie`i',keep(FRDM EN year INDTYPE REGTYPE GIOV_CR PERSENG TOIPT SI TWC NAR STOCK FA TA CL TL F334)
}
rename F334 RND
append using cie2007,keep(FRDM EN year INDTYPE REGTYPE GIOV_CR PERSENG TOIPT SI TWC NAR STOCK FA TA CL TL RND)
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
merge n:1 year using "D:\Project A\deflator\inv_deflator.dta",nogen keep(matched)
*add registration type
gen ownership="SOE" if (REGTYPE=="110" | REGTYPE=="141" | REGTYPE=="143" | REGTYPE=="151"  )
replace ownership="DPE" if (REGTYPE=="120" | REGTYPE=="130" | REGTYPE=="142" | REGTYPE=="149" | REGTYPE=="159" | REGTYPE=="160" | REGTYPE=="170" | REGTYPE=="171" | REGTYPE=="172" | REGTYPE=="173" | REGTYPE=="174" | REGTYPE=="190")
replace ownership="JV" if ( REGTYPE=="210" | REGTYPE=="220" | REGTYPE=="310" | REGTYPE=="320" )
replace ownership="MNE" if ( REGTYPE=="230" | REGTYPE=="240" | REGTYPE=="330" | REGTYPE=="340" )
count if ownership==""
replace ownership="SOE" if ownership==""
sort FRDM year
format EN %30s
cd "D:\Project C\sample_matched\CIE"
save cie_98_07,replace

*-------------------------------------------------------------------------------
* Markup estimation according to 
cd "D:\Project C\sample_matched\CIE"
use cie_98_07,clear
*********************
*Step 1
*********************
egen newid=group(FRDM)
gen y_output=log(GIOV_CR/OutputDefl)
gen rkap1=FA/inv_deflator
gen realmat=TOIPT/InputDefl  /*real material input*/
gen k=log(rkap1)
gen m=log(realmat)
gen l=log(PERSENG)
drop if y_output==. | l==. | k==.| m==.
save cie_98_07_newid,replace

use cie_98_07_newid,clear
tsset newid year, yearly
local M=3
local N=3
forvalues i=1/`M' {
gen l`i'=l^(`i')
gen m`i'=m^(`i')
gen k`i'=k^(`i')
local `N'=`M'-`i'
*interaction terms
forvalues j=1/`N' {
gen l`i'm`j'=l^(`i')*m^(`j')
gen l`i'k`j'=l^(`i')*k^(`j')
gen k`i'm`j'=k^(`i')*m^(`j')
}
}
gen l1k1m1=l*k*m

xi: reg y_output l1 k1 m1 l2 k2 m2 l1k1 l1m1 k1m1 l3 k3 m3 l2k1 l2m1 l1k2 k2m1 l1m2 k1m2 l1k1m1 i.year

local varlist "l1 k1 m1 l2 k2 m2 l1k1 l1m1 k1m1 l3 k3 m3 l2k1 l2m1 l1k2 k2m1 l1m2 k1m2 l1k1m1"
foreach var of local varlist {
	gen b`var'ols = _b[`var']
}

gen b_mOLS=bm1ols+2*bm2ols*m1+bl1m1ols*l1+bk1m1ols*k1+3*bm3ols*m2+bl2m1ols*l2+bk2m1ols*k2 + 2*bl1m2ols*l1m1+2*bk1m2ols*k1m1+bl1k1m1ols*l1k1 

*------FIRST STAGE------
xi: reg y_output l* k* m* i.year

*ask e*(l* m* k*)
predict phi
predict epsilon, res
label var phi "phi_it"
label var epsilon "measurement error first stage"

gen phi_lag=L.phi
local varlist "l k m"
foreach var of local varlist {
	gen `var'_lag=L.`var'
	gen `var'_lag2=`var'_lag^2
	gen `var'_lag3=`var'_lag^3
}

gen l_lagk=l_lag*k
gen l_lagk2=l_lag*k^2
gen l_lagk_lag=l_lag*k_lag
gen l_lagk_lag2=l_lag*k_lag^2
gen l_lag2k=l_lag^2*k
gen l_lag2k_lag=l_lag^2*k_lag

gen km_lag=m_lag*k
gen km_lag2=m_lag^2*k
gen k2m_lag=m_lag*k^2
gen k_lagm_lag=m_lag*k_lag
gen k_lag2m_lag=m_lag*k_lag^2
gen k_lagm_lag2=m_lag^2*k_lag

gen l_lagm_lag=l_lag*m_lag
gen l_lag2m_lag=l_lag^2*m_lag
gen l_lagm_lag2=l_lag*m_lag^2


gen l_lagkm_lag=l_lag*k*m_lag
gen l_lagk_lagm_lag=l_lag*k_lag*m_lag

gen alpha_m=TOIPT/GIOV_CR 
drop _I*
sort newid year
gen const=1
drop if y_output==. | l_lag==. | k_lag==. | m_lag==. | phi==. | phi_lag==.

*********************
*Step 2
*********************
gmm (phi-{betal}*l1-{betak}*k1-{betam}*m1-{betal2}*l2-{betak2}*k2-{betam2}*m2-{betalk}*l1k1-{betalm}*l1m1-{betakm}*k1m1 ///
- {betal3}*l3 - {betak3}*k3 - {betam3}*m3 - {betal2k1}*l2k1 - {betal2m1}*l2m1 - {betal1k2}*l1k2 - {betak2m1}*k2m1 - {betal1m2}*l1m2 - {betak1m2}*k1m2 - {betalkm}*l1k1m1  ///
-{alpha1}*(phi_lag-{betal}*l_lag-{betak}*k_lag-{betam}*m_lag-{betal2}*l_lag2-{betak2}*k_lag2-{betam2}*m_lag2-{betalk}*l_lagk_lag-{betalm}*l_lagm_lag-{betakm}*k_lagm_lag  ///
- {betal3}*l_lag3 - {betak3}*k_lag3 - {betam3}*m_lag3 - {betal2k1}*l_lag2k_lag - {betal2m1}*l_lag2m_lag - {betal1k2}*l_lagk_lag2 - {betak2m1}*k_lag2m_lag - {betal1m2}*l_lagm_lag2 - {betak1m2}*k_lagm_lag2 - {betalkm}*l_lagk_lagm_lag) ///
-{alpha2}*(phi_lag-{betal}*l_lag-{betak}*k_lag-{betam}*m_lag-{betal2}*l_lag2-{betak2}*k_lag2-{betam2}*m_lag2-{betalk}*l_lagk_lag-{betalm}*l_lagm_lag-{betakm}*k_lagm_lag  ///
- {betal3}*l_lag3 - {betak3}*k_lag3 - {betam3}*m_lag3 - {betal2k1}*l_lag2k_lag - {betal2m1}*l_lag2m_lag - {betal1k2}*l_lagk_lag2 - {betak2m1}*k_lag2m_lag - {betal1m2}*l_lagm_lag2 - {betak1m2}*k_lagm_lag2 - {betalkm}*l_lagk_lagm_lag)^2  ///
-{alpha3}*(phi_lag-{betal}*l_lag-{betak}*k_lag-{betam}*m_lag-{betal2}*l_lag2-{betak2}*k_lag2-{betam2}*m_lag2-{betalk}*l_lagk_lag-{betalm}*l_lagm_lag-{betakm}*k_lagm_lag  ///
- {betal3}*l_lag3 - {betak3}*k_lag3 - {betam3}*m_lag3 - {betal2k1}*l_lag2k_lag - {betal2m1}*l_lag2m_lag - {betal1k2}*l_lagk_lag2 - {betak2m1}*k_lag2m_lag - {betal1m2}*l_lagm_lag2 - {betak1m2}*k_lagm_lag2 - {betalkm}*l_lagk_lagm_lag)^3)  ///
, instruments(k1 k2 k3 l_lag m_lag k_lag l_lag2 k_lag2 m_lag2 l_lag3 k_lag3 m_lag3 km_lag km_lag2 k2m_lag k_lagm_lag k_lag2m_lag k_lagm_lag2 l_lagm_lag l_lag2m_lag l_lagm_lag2 ///
 l_lagk l_lagk2 l_lagk_lag l_lagk_lag2 l_lag2k l_lag2k_lag l_lagkm_lag l_lagk_lagm_lag)
 
gen betal1_tld=_b[/betal]
gen betak1_tld=_b[/betak]
gen betam1_tld=_b[/betam]
gen betal2_tld=_b[/betal2]
gen betak2_tld=_b[/betak2]
gen betam2_tld=_b[/betam2]
gen betal1k1_tld=_b[/betalk]
gen betal1m1_tld=_b[/betalm]
gen betak1m1_tld=_b[/betakm]

gen betal3_tld=_b[/betal3]
gen betak3_tld=_b[/betak3]
gen betam3_tld=_b[/betam3]
gen betal2k1_tld = _b[/betal2k1]
gen betal2m1_tld = _b[/betal2m1]
gen betal1k2_tld = _b[/betal1k2]
gen betak2m1_tld = _b[/betak2m1]
gen betal1m2_tld = _b[/betal1m2]
gen betak1m2_tld = _b[/betak1m2]
gen betalkm_tld = _b[/betalkm]

gen betam_tld=betam1_tld+2*betam2_tld*m1+betal1m1_tld*l1+betak1m1_tld*k1+3*betam3_tld*m2+betal2m1_tld*l2+betak2m1_tld*k2 + 2*betal1m2_tld*l1m1+2*betak1m2_tld*k1m1+betalkm_tld*l1k1 

gen Markup_ols=b_mOLS/alpha_m
gen Markup_DLWTLD=betam_tld/alpha_m
sum Markup_ols Markup_DLWTLD, detail
keep year FRDM newid Markup_ols Markup_DLWTLD betal1_tld betak1_tld betam1_tld betal2_tld betak2_tld betam2_tld betal1k1_tld betal1m1_tld betak1m1_tld  betal3_tld betak3_tld betam3_tld betal2k1_tld betal2m1_tld betal1k2_tld betak2m1_tld betal1m2_tld betak1m2_tld betalkm_tld
cd "D:\Project C\markup"
save cie_99_07_markup_beta.dta,replace

use cie_99_07_markup_beta.dta,clear
merge 1:1 newid year using "D:\Project C\sample_matched\CIE\cie_98_07_newid",nogen keep(matched)
tab year
gen tfp_tld= y_output - betal1_tld*l- betak1_tld*k- betam1_tld*m -betal2_tld*l*l- betak2_tld*k*k- betam2_tld*m*m- betal1k1_tld*l*k- betal1m1_tld*l*m - betak1m1_tld*k*m ///
 - betal3_tld*l*l*l - betak3_tld*k*k*k - betam3_tld*m*m*m - betal2k1_tld*l*l*k - betal2m1_tld*l*l*m - betal1k2_tld*l*k*k - betak2m1_tld*k*k*m - betal1m2_tld*l*m*m - betak1m2_tld*k*m*m - betalkm_tld*l*k*m 
compress
save cie_99_07_markup, replace

cd "D:\Project C\markup"
use cie_99_07_markup,clear
destring INDTYPE,replace
merge 1:1 FRDM year using cie9907markup
* 1256199 matched, 58609 master, 2132 using
keep FRDM year EN tfp_tld Markup_*
sort FRDM year
by FRDM: gen Markup_lag=Markup_DLWTLD[_n-1] if year==year[_n-1]+1
by FRDM: egen Markup_avg=mean(Markup_DLWTLD)
by FRDM: gen tfp_lag=tfp_tld[_n-1] if year==year[_n-1]+1
by FRDM: egen tfp_avg=mean(tfp_tld)
save cie_99_07_markup_merged,replace

*-------------------------------------------------------------------------------
* Add financial vulnerability measures to firm data
cd "D:\Project C\sample_matched\CIE"
use cie_98_07,clear
keep if year>=1999
gen IND2=substr(INDTYPE,1,2)
* Add markup and tfp info
merge 1:1 FRDM year using "D:\Project C\markup\cie_99_07_markup_merged", nogen keepus(Markup_* tfp_*) keep(matched master)
sum Markup_*,detail
winsor2 Markup_*, trim replace by (year IND2)
sum tfp_*,detail
winsor2 Markup_*, trim replace by (year IND2)
* Calculate CIE info
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
pca ExtFin_US Tang_US
factor ExtFin_US Tang_US,pcf
factortest ExtFin_US Tang_US
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
* Merge customs data with CIE data
cd "D:\Project C\sample_matched"
use customs_matched,clear
keep if exp_imp =="exp"
drop exp_imp
merge n:1 FRDM year using ".\customs_twoway_list",nogen keep(matched) keepus(twoway_trade)
merge n:1 FRDM year using ".\CIE\cie_credit",nogen keep(matched)
merge n:1 HS6 using "D:\Project C\GVC\ups_cmy_HS6_07",nogen keep(matched)
foreach key in 贸易 外贸 经贸 工贸 科贸 商贸 边贸 技贸 进出口 进口 出口 物流 仓储 采购 供应链 货运{
	drop if strmatch(EN, "*`key'*") 
}
bys FRDM year: egen weight=pc(value_year),prop
bys FRDM year: egen ups_firm=sum(ups_HS6*weight)
xtile ups_firm_xt4=ups_firm,nq(4)
bys HS6 coun_aim year: egen MS=pc(value_year),prop
xtile MS_xt4=MS,nq(4)
gen MS_sqr=MS^2
sort FRDM HS6 coun_aim year
by FRDM HS6 coun_aim: gen dlnprice=ln(price_RMB)-ln(price_RMB[_n-1]) if year==year[_n-1]+1
by FRDM HS6 coun_aim: egen year_count=count(year)
drop if year_count<=1
drop if HS2=="93"|HS2=="97"|HS2=="98"|HS2=="99"
egen group_id=group(FRDM HS2 coun_aim)
winsor2 dlnprice, trim by(HS2 year)
local varlist "FPC_US ExtFin_US Tang_US ExtFin_cic2 Tang_cic2 Invent_cic2 RDint_cic2 Cash_cic2 Liquid_cic2 Levg_cic2 Tang Invent RDint Cash Liquid Levg MS MS_sqr ups_HS6 ups_firm Markup_ols Markup_DLWTLD tfp_tld"
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
eststo exp_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year, a(group_id)
eststo exp_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year, a(group_id)
eststo exp_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year, a(group_id)

estfe exp_baseline exp_FPC_US exp_ExtFin_US exp_Tang_US, labels(group_id "Firm-product-country FE")
esttab exp_baseline exp_FPC_US exp_ExtFin_US exp_Tang_US using "D:\Project C\tables\table_exp_matched_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Baseline" "FPC" "External Finance" "Tangibility")

eststo exp_ExtFin_cic2: areg dlnprice_tr dlnRER x_ExtFin_cic2 dlnrgdp i.year, a(group_id)
eststo exp_Tang_cic2: areg dlnprice_tr dlnRER x_Tang_cic2 dlnrgdp i.year, a(group_id)
eststo exp_Invent_cic2: areg dlnprice_tr dlnRER x_Invent_cic2 dlnrgdp i.year, a(group_id)
eststo exp_RDint_cic2: areg dlnprice_tr dlnRER x_RDint_cic2 dlnrgdp i.year, a(group_id)

estfe exp_baseline exp_ExtFin_cic2 exp_Tang_cic2 exp_Invent_cic2 exp_RDint_cic2, labels(group_id "Firm-product-country FE")
esttab exp_baseline exp_ExtFin_cic2 exp_Tang_cic2 exp_Invent_cic2 exp_RDint_cic2 using "D:\Project C\tables\table_exp_matched_CN.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Baseline" "External Finance" "Tangibility" "Inventory" "R&D Intensity")

eststo exp_MS: areg dlnprice_tr dlnRER dlnrgdp MS x_MS i.year, a(group_id)
eststo exp_MS_sqr: areg dlnprice_tr dlnRER dlnrgdp MS x_MS x_MS_sqr i.year, a(group_id)
estfe exp_MS_*, labels(group_id "Firm-product-country FE")
esttab exp_MS_* using "D:\Project C\tables\table_exp_MS.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("MS" "MS^2")

forv i=1/4{
	eststo exp_MS4_`i': qui areg dlnprice_tr dlnRER dlnrgdp i.year if MS_xt4==`i', a(group_id)	
}
estfe exp_MS4_*, labels(group_id "Firm-product-country FE")
esttab exp_MS4_* using "D:\Project C\tables\table_exp_MS_xt4.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles( "1st" "2nd" "3rd" "4th")

*-------------------------------------------------------------------------------
* Regressions with upstreamness
cd "D:\Project C\sample_matched"
use sample_matched_exp,clear

eststo exp_ups_HS6: areg dlnprice_tr dlnRER x_ups_HS6 dlnrgdp i.year, a(group_id)
eststo exp_ups_firm: areg dlnprice_tr dlnRER x_ups_firm dlnrgdp i.year, a(group_id)

gen x_ExtFin_US_ups_HS6=x_ExtFin_US*ups_HS6
gen x_ExtFin_US_ups_firm=x_ExtFin_US*ups_firm
eststo exp_ExtFin_US_ups_HS6: qui areg dlnprice_tr dlnRER x_ExtFin_US x_ups_HS6 x_ExtFin_US_ups_HS6 dlnrgdp i.year, a(group_id)
eststo exp_ExtFin_US_ups_firm: qui areg dlnprice_tr dlnRER x_ExtFin_US x_ups_firm x_ExtFin_US_ups_firm dlnrgdp i.year, a(group_id)

gen x_Tang_US_ups_HS6=x_Tang_US*ups_HS6
gen x_Tang_US_ups_firm=x_Tang_US*ups_firm
eststo exp_Tang_US_ups_HS6: qui areg dlnprice_tr dlnRER x_Tang_US x_ups_HS6 x_Tang_US_ups_HS6 dlnrgdp i.year, a(group_id)
eststo exp_Tang_US_ups_firm: qui areg dlnprice_tr dlnRER x_Tang_US x_ups_firm x_Tang_US_ups_firm dlnrgdp i.year, a(group_id)

estfe exp_ExtFin_US exp_Tang_US exp_ups_HS6 exp_ups_firm exp_ExtFin_US_ups_HS6 exp_ExtFin_US_ups_firm exp_Tang_US_ups_HS6 exp_Tang_US_ups_firm, labels(group_id "Firm-product-country FE")
esttab exp_ExtFin_US exp_Tang_US exp_ups_HS6 exp_ups_firm exp_ExtFin_US_ups_HS6 exp_ExtFin_US_ups_firm exp_Tang_US_ups_HS6 exp_Tang_US_ups_firm using "D:\Project C\tables\table_exp_ups_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp) mtitle( "ExtFin" "Tang" "UPS_HS6" "UPS_firm" "ExtFin*UPS_HS6" "ExtFin*UPS_firm" "Tang*UPS_HS6" "Tang*UPS_firm")

*-------------------------------------------------------------------------------
* Regressions controlling firms' markup and TFP
cd "D:\Project C\sample_matched"
use sample_matched_exp,clear

eststo exp_markup: areg dlnprice_tr dlnRER x_Markup_DLWTLD dlnrgdp MS Markup_DLWTLD tfp_tld i.year, a(group_id)
eststo exp_ExtFin_US_markup: areg dlnprice_tr dlnRER x_ExtFin_US x_Markup_DLWTLD dlnrgdp MS Markup_DLWTLD tfp_tld i.year, a(group_id)
eststo exp_Tang_US_markup: areg dlnprice_tr dlnRER x_Tang_US x_Markup_DLWTLD MS Markup_DLWTLD tfp_tld dlnrgdp i.year, a(group_id)

estfe exp_markup exp_ExtFin_US_markup exp_Tang_US_markup, labels(group_id "Firm-product-country FE")
esttab exp_markup exp_ExtFin_US_markup exp_Tang_US_markup using "D:\Project C\tables\table_exp_markup.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp x_*)

eststo exp_tfp: areg dlnprice_tr dlnRER x_tfp_tld dlnrgdp MS Markup_DLWTLD tfp_tld i.year, a(group_id)
eststo exp_ExtFin_US_tfp: areg dlnprice_tr dlnRER x_ExtFin_US x_tfp_tld dlnrgdp MS Markup_DLWTLD tfp_tld i.year, a(group_id)
eststo exp_Tang_US_tfp: areg dlnprice_tr dlnRER x_Tang_US x_tfp_tld MS Markup_DLWTLD tfp_tld dlnrgdp i.year, a(group_id)

estfe exp_tfp exp_ExtFin_US_tfp exp_Tang_US_tfp, labels(group_id "Firm-product-country FE")
esttab exp_tfp exp_ExtFin_US_tfp exp_Tang_US_tfp using "D:\Project C\tables\table_exp_tfp.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp x_*)

*-------------------------------------------------------------------------------
* Use the same method to construct import sample
cd "D:\Project C\sample_matched"
use customs_matched,clear
keep if exp_imp =="imp"
drop exp_imp
merge n:1 FRDM year using ".\customs_twoway_list",nogen keep(matched) keepus(twoway_trade)
merge n:1 FRDM year using ".\CIE\cie_credit",nogen keep(matched)
merge n:1 HS6 using "D:\Project C\GVC\ups_cmy_HS6_07",nogen keep(matched)
foreach key in 贸易 外贸 经贸 工贸 科贸 商贸 边贸 技贸 进出口 进口 出口 物流 仓储 采购 供应链 货运{
	drop if strmatch(EN, "*`key'*") 
}
bys FRDM year: egen weight=pc(value_year),prop
bys FRDM year: egen ups_firm=sum(ups_HS6*weight)
xtile ups_firm_xt4=ups_firm,nq(4)
bys HS6 coun_aim year: egen MS=pc(value_year),prop
xtile MS_xt4=MS,nq(4)
gen MS_sqr=MS^2
sort FRDM HS6 coun_aim year
by FRDM HS6 coun_aim: gen dlnprice=ln(price_RMB)-ln(price_RMB[_n-1]) if year==year[_n-1]+1
by FRDM HS6 coun_aim: egen year_count=count(year)
drop if year_count<=1
drop if HS2=="93"|HS2=="97"|HS2=="98"|HS2=="99"
egen group_id=group(FRDM HS2 coun_aim)
winsor2 dlnprice, trim by(HS2 year)
local varlist "FPC_US ExtFin_US Tang_US ExtFin_cic2 Tang_cic2 Invent_cic2 RDint_cic2 Cash_cic2 Liquid_cic2 Levg_cic2 Tang Invent RDint Cash Liquid Levg MS MS_sqr ups_HS6 ups_firm Markup_DLWTLD tfp_tld Markup_lag tfp_lag Markup_avg tfp_avg"
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
eststo imp_FPC_US: areg dlnprice_tr dlnRER x_FPC_US dlnrgdp i.year, a(group_id)
eststo imp_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year, a(group_id)
eststo imp_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year, a(group_id)

estfe imp_baseline imp_FPC_US imp_ExtFin_US imp_Tang_US, labels(group_id "Firm-product-country FE")
esttab imp_baseline imp_FPC_US imp_ExtFin_US imp_Tang_US using "D:\Project C\tables\table_imp_matched_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Baseline" "FPC" "External Finance" "Tangibility")

eststo imp_ExtFin_cic2: areg dlnprice_tr dlnRER x_ExtFin_cic2 dlnrgdp i.year, a(group_id)
eststo imp_Tang_cic2: areg dlnprice_tr dlnRER x_Tang_cic2 dlnrgdp i.year, a(group_id)
eststo imp_Invent_cic2: areg dlnprice_tr dlnRER x_Invent_cic2 dlnrgdp i.year, a(group_id)
eststo imp_RDint_cic2: areg dlnprice_tr dlnRER x_RDint_cic2 dlnrgdp i.year, a(group_id)

estfe imp_baseline imp_ExtFin_cic2 imp_Tang_cic2 imp_Invent_cic2 imp_RDint_cic2, labels(group_id "Firm-product-country FE")
esttab imp_baseline imp_ExtFin_cic2 imp_Tang_cic2 imp_Invent_cic2 imp_RDint_cic2 using "D:\Project C\tables\table_imp_matched_CN.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("Baseline" "External Finance" "Tangibility" "Inventory" "R&D Intensity")

eststo imp_MS: areg dlnprice_tr dlnRER dlnrgdp MS x_MS i.year, a(group_id)
eststo imp_MS_sqr: areg dlnprice_tr dlnRER dlnrgdp MS x_MS x_MS_sqr i.year, a(group_id)
estfe imp_MS imp_MS_sqr, labels(group_id "Firm-product-country FE")
esttab imp_MS imp_MS_sqr using "D:\Project C\tables\table_imp_MS.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles("MS" "MS^2")

forv i=1/4{
	eststo imp_MS4_`i': qui areg dlnprice_tr dlnRER dlnrgdp i.year if MS_xt4==`i', a(group_id)	
}
estfe imp_MS4_*, labels(group_id "Firm-product-country FE")
esttab imp_MS4_* using "D:\Project C\tables\table_imp_MS_xt4.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') mtitles( "1st" "2nd" "3rd" "4th")

*-------------------------------------------------------------------------------
* Regressions with upstreamness
cd "D:\Project C\sample_matched"
use sample_matched_imp,clear

eststo imp_ExtFin_US: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp i.year MS, a(group_id)
eststo imp_Tang_US: areg dlnprice_tr dlnRER x_Tang_US dlnrgdp i.year MS, a(group_id)

eststo imp_ups_HS6: areg dlnprice_tr dlnRER x_ups_HS6 dlnrgdp MS i.year, a(group_id)

gen x_ExtFin_US_ups_HS6=x_ExtFin_US*ups_HS6
eststo imp_ExtFin_US_ups_HS6: areg dlnprice_tr dlnRER x_ExtFin_US x_ups_HS6 x_ExtFin_US_ups_HS6 dlnrgdp MS i.year, a(group_id)

gen x_Tang_US_ups_HS6=x_Tang_US*ups_HS6
eststo imp_Tang_US_ups_HS6: areg dlnprice_tr dlnRER x_Tang_US x_ups_HS6 x_Tang_US_ups_HS6 dlnrgdp MS i.year, a(group_id)

estfe imp_ups_HS6 imp_ExtFin_US imp_Tang_US imp_ExtFin_US_ups_HS6 imp_Tang_US_ups_HS6, labels(group_id "Firm-product-country FE")
esttab imp_ups_HS6 imp_ExtFin_US imp_Tang_US imp_ExtFin_US_ups_HS6 imp_Tang_US_ups_HS6 using "D:\Project C\tables\table_imp_ups_HS6_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp) drop(MS) mtitle("Upstream" "ExtFin" "Tang" "ExtFin*Upstream" "Tang*Upstream")

eststo imp_ups_firm: areg dlnprice_tr dlnRER x_ups_firm dlnrgdp MS i.year, a(group_id)

gen x_ExtFin_US_ups_firm=x_ExtFin_US*ups_firm
eststo imp_ExtFin_US_ups_firm: areg dlnprice_tr dlnRER x_ExtFin_US x_ups_firm x_ExtFin_US_ups_firm dlnrgdp i.year, a(group_id)

gen x_Tang_US_ups_firm=x_Tang_US*ups_firm
eststo imp_Tang_US_ups_firm: areg dlnprice_tr dlnRER x_Tang_US x_ups_firm x_Tang_US_ups_firm dlnrgdp MS i.year, a(group_id)

estfe imp_ups_firm imp_ExtFin_US imp_Tang_US imp_ExtFin_US_ups_firm imp_Tang_US_ups_firm, labels(group_id "Firm-product-country FE")
esttab imp_ups_firm imp_ExtFin_US imp_Tang_US imp_ExtFin_US_ups_firm imp_Tang_US_ups_firm using "D:\Project C\tables\table_imp_ups_firm_US.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp) drop(MS) mtitle("Upstream" "ExtFin" "Tang" "ExtFin*Upstream" "Tang*Upstream")

*-------------------------------------------------------------------------------
* Regressions using the subsample of twoway traders
cd "D:\Project C\sample_matched"
use sample_matched_imp,clear

eststo imp_baseline_twoway: areg dlnprice_tr dlnRER dlnrgdp MS i.year if twoway_trade==1, a(group_id)
eststo imp_baseline_oneway: areg dlnprice_tr dlnRER dlnrgdp MS i.year if twoway_trade==0, a(group_id)

eststo imp_ExtFin_US_twoway: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp MS i.year if twoway_trade==1, a(group_id)
eststo imp_ExtFin_US_oneway: areg dlnprice_tr dlnRER x_ExtFin_US dlnrgdp MS i.year if twoway_trade==0, a(group_id)

*-------------------------------------------------------------------------------
* Regressions controlling firms' markup and TFP
cd "D:\Project C\sample_matched"
use sample_matched_imp,clear

eststo imp_markup: areg dlnprice_tr dlnRER x_Markup_lag dlnrgdp MS Markup_lag tfp_lag i.year, a(group_id)

eststo imp_ExtFin_US_markup: areg dlnprice_tr dlnRER x_ExtFin_US x_Markup_lag dlnrgdp MS Markup_lag tfp_lag i.year, a(group_id)
eststo imp_Tang_US_markup: areg dlnprice_tr dlnRER x_Tang_US x_Markup_lag MS Markup_lag tfp_lag dlnrgdp i.year, a(group_id)

estfe imp_markup imp_ExtFin_US_markup imp_Tang_US_markup, labels(group_id "Firm-product-country FE")
esttab imp_markup imp_ExtFin_US_markup imp_Tang_US_markup using "D:\Project C\tables\table_imp_markup.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp x_*)

eststo imp_tfp: areg dlnprice_tr dlnRER x_tfp_lag dlnrgdp MS Markup_lag tfp_lag i.year, a(group_id)
eststo imp_ExtFin_US_tfp: areg dlnprice_tr dlnRER x_ExtFin_US x_tfp_lag dlnrgdp MS Markup_lag tfp_lag i.year, a(group_id)
eststo imp_Tang_US_tfp: areg dlnprice_tr dlnRER x_Tang_US x_tfp_lag dlnrgdp MS Markup_lag tfp_lag i.year, a(group_id)

estfe imp_tfp imp_ExtFin_US_tfp imp_Tang_US_tfp, labels(group_id "Firm-product-country FE")
esttab imp_tfp imp_ExtFin_US_tfp imp_Tang_US_tfp using "D:\Project C\tables\table_imp_tfp.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp x_*)

estfe imp_markup imp_ExtFin_US_markup imp_Tang_US_markup imp_tfp imp_ExtFin_US_tfp imp_Tang_US_tfp, labels(group_id "Firm-product-country FE")
esttab imp_markup imp_ExtFin_US_markup imp_Tang_US_markup imp_tfp imp_ExtFin_US_tfp imp_Tang_US_tfp using "D:\Project C\tables\table_imp_markup_tfp.csv", replace b(3) se(3) noconstant starlevels(* 0.1 ** 0.05 *** 0.01) indicate("Year FE =*.year" `r(indicate_fe)') order(dlnRER dlnrgdp x_*_lag x_*_US)