/*Date:20171008*/
/*Purpose: ML data preparement*/
clear all 
set more off
//set maxvar 32767
capture log close
cd "/home/wine2/new_data_20170425/"  /*set the file location*/

use "00_wine_pageview_filter_member.dta" ,clear
drop wine_list buy tag_buy non_purchase client_id customerid // drop redundant 
sort visitor_id session_id date_time log_id
// the reg_state process is done in the previous do.file

/* First we should create the history_id variable */
gen order=1 if order_id!=""
replace order=0 if order==.
by visitor_id session_id: egen os=max(order)
by visitor_id session_id: gen ps=1 if os!=0
replace ps=0 if ps==.
drop order os 
gen his=1 
gen history_id= sum(his) if visitor_id[_n]!=visitor_id[_n-1] | (ps[_n]!=ps[_n-1] & ps!=1) 
replace history_id=history_id[_n-1] if history_id==.
//sort history_id session_id
//by history_id session_id:gen oobs=_n // oobs is # of visits before purchase session 
// history_id is the record for each purchase-history

// Create order: whether the order sent in this history
bysort history_id: egen tag_order=max(ps)
bysort history_id: gen order=1 if tag_order!=0
replace order=0 if order==.
drop tag_order
/******* Following is the process of extracting a-month history record ********/
// Duration before the purchase-session
sort history_id session_id date_time
by history_id session_id: gen dur= date_time[_N]-date_time[1] // dur= duration for this session
by history_id: egen duration=total(dur) // duration= the duration spent on website for this history_id
replace duration=duration/60000 // now the unit of duration is minute
replace dur= dur/1000 // since the unit is millisecond
by history_id session_id:gen obss=_n // obss is the # of transaction in each session
//replace dur=0 if obss!=1
sort history_id
//by history_id: egen duration= total(dur) // duration is the total-time spent before purchase-session
by history_id: egen visit=total(obss) if obss==1
by history_id: egen DP=mean(dur) if obss==1 
by history_id: replace DP=DP[_n-1] if DP==. & _n!=1 // fill in the missing value, can do it later
// Pages viewed before pruchase-session
by history_id: gen obsss=_n
by history_id: egen pages=max(obsss) // pages mean the # of pages before purchase-session
by history_id: egen VP=mean(pages) if obss==1
by history_id: replace VP=VP[_n-1] if VP==. & _n!=1 // fill in the missing value, can do it later

/* First, we should know the distribution for the purchase-history, so as to select the correct control group */
histogram duration if order==1 & obsss==1, frequency kdensity

// var: month of purchase-session
gen datetime= dofc(date_time)
gen month= month(datetime) 
tostring month, replace
replace month="Jan" if month=="1"
replace month="Feb" if month=="2"
replace month="Mar" if month=="3"
replace month="Apr" if month=="4"
replace month="May" if month=="5"
replace month="Jun" if month=="6"
replace month="Jul" if month=="7"
replace month="Aug" if month=="8"
replace month="Sep" if month=="9"
replace month="Oct" if month=="10"
replace month="Nov" if month=="11"
replace month="Dec" if month=="12"
// select a month transaction between the purchase/unpurchase session
sort history_id date_time
by history_id: gen mm=1
by history_id: gen mon=sum(mm) if month[_n]!=month[_n-1] 
by history_id: replace mon=mon[_n-1] if mon==.
drop mm
by history_id: egen Mon=max(mon)
by history_id: drop if mon>2 & order==0
by history_id: keep if order==0 | (mon==Mon & order==1) | (mon==Mon-1 & order==1)
drop dur duration obss visit DP obsss pages VP datetime month
/********** Now all the history_id is a month record history ******************/

// Merge with cluster3 result
merge n:1 history_id using "cluster3.dta" 
replace cluster3=1 if cluster3==25739
replace cluster3=2 if cluster3==5316
replace cluster3=3 if cluster3==41432
replace cluster3=4 if cluster==.
drop _merge


/* Create the features depending on history_id */
// Duration before the purchase-session
sort history_id session_id date_time
by history_id session_id: gen dur= date_time[_N]-date_time[1] // dur= duration for this session
by history_id: egen duration=total(dur) // duration= the duration spent on website for this history_id
replace duration=duration/1000 // now the unit of duration is day
replace dur= dur/1000 // since the unit is millisecond
by history_id session_id:gen obss=_n // obss is the # of transaction in each session
//replace dur=0 if obss!=1
sort history_id
//by history_id: egen duration= total(dur) // duration is the total-time spent before purchase-session
by history_id: egen visit=total(obss) if obss==1
by history_id: egen DP=mean(dur) if obss==1 
by history_id: replace DP=DP[_n-1] if DP==. & _n!=1 // fill in the missing value, can do it later

// Pages viewed before pruchase-session
by history_id: gen obsss=_n
by history_id: egen pages=max(obsss) // pages mean the # of pages before purchase-session
by history_id: egen VP=mean(pages) if obss==1
by history_id: replace VP=VP[_n-1] if VP==. & _n!=1 // fill in the missing value, can do it later

// var: month of purchase-session
gen datetime= dofc(date_time)
gen month= month(datetime) 
tostring month, replace
gsort history_id -order_id
by history_id: replace month=month[_n-1] if order==1 & _n!=1
gsort history_id -date_time
by history_id: replace month=month[_n-1] if order==0 & _n!=1
replace month="Jan" if month=="1"
replace month="Feb" if month=="2"
replace month="Mar" if month=="3"
replace month="Apr" if month=="4"
replace month="May" if month=="5"
replace month="Jun" if month=="6"
replace month="Jul" if month=="7"
replace month="Aug" if month=="8"
replace month="Sep" if month=="9"
replace month="Oct" if month=="10"
replace month="Nov" if month=="11"
replace month="Dec" if month=="12"

//by history_id: gen DPP=duration/pages
/*
///pages-type viewed before purchase-session
// Main pages viewed before purchase-session
gen tag_mainpage=1 if page_type=="main_wine"
replace tag_mainpage=0 if tag_mainpage==.
by history_id: egen mpage=total(tag_mainpage)
drop tag_mainpage

// Wine-list pages viewed before purchase-session
gen tag_winelist=1 if page_type=="list_wine"
replace tag_winelist=0 if tag_winelist==.
by history_id: egen wlpage=total(tag_winelist)
drop tag_winelist

// Wine-detail pages viewed before purchase-session
gen tag_winedetail=1 if page_type=="wine_detail"
replace tag_winedetail=0 if tag_winedetail==.
by history_id: egen wdpage=total(tag_winedetail)
drop tag_winedetail

// Wine-intro pages viewed before purchase-session
gen tag_wineintro=1 if page_type=="winery_intro"
replace tag_wineintro=0 if tag_wineintro==.
by history_id: egen wipage=total(tag_wineintro)
drop tag_wineintro
*/

/*
/// Filter-type used before purchase-session
// To create the X as the info. of using filter
by history_id: gen obs=_n
gen tag_usef=1 if filter_cat1!="" // tag_usef means visitor do use filter at this timing
by history_id: egen sumtagf=total(tag_usef)
by history_id: gen usef=1 if sumtagf>0 // usef means this visitor do use the filter among his visiting sessions
replace usef=0 if usef==.
keep if (usef==0 & obs==1) | (usef==1 & tag_usef==1) // to let reshape-process be quickly
drop obs // since the previous process will broke the sturcture of obs
by history_id: gen obs=_n
by history_id: keep if obs<=3 // for the visitor who use visitor, if his obs!=1&2&3, then it is not the first timing of using filter
by history_id: gen multi=1 if filter_cat2!="" & usef==1
replace multi=0 if multi==. & usef==1
tab multi if obs==1 & usef==1
drop if multi==1 // since the ratio of multi-choice is low, we drop it.
drop multi tag_usef sumtagf
drop filter_code2 filter_str2 filter_cat2 filter_code3 filter_str3 filter_cat3 filter_code4 filter_str4 filter_cat4 filter_code5 filter_str5 filter_cat5 filter_code6 filter_str6 filter_cat6 filter_code7 filter_str7 filter_cat7 filter_code8 filter_str8 filter_cat8 filter_code9 filter_str9 filter_cat9 filter_code10 filter_str10 filter_cat10 filter_code11 filter_str11 filter_cat11 filter_code12 filter_str12 filter_cat12 filter_code13 filter_str13 filter_cat13 filter_code14 filter_str14 filter_cat14 filter_code15 filter_str15 filter_cat15 filter_code16 filter_str16 filter_cat16 filter_code17 filter_str17 filter_cat17 filter_code18 filter_str18 filter_cat18 filter_code19 filter_str19 filter_cat19 filter_code20 filter_str20 filter_cat20 filter_code21 filter_str21 filter_cat21 filter_code22 filter_str22 filter_cat22 filter_code23 filter_str23 filter_cat23 filter_code24 filter_str24 filter_cat24 filter_code25 filter_str25 filter_cat25 filter_code26 filter_str26 filter_cat26 filter_code27 filter_str27 filter_cat27 filter_code28 filter_str28 filter_cat28 filter_code29 filter_str29 filter_cat29 filter_code30 filter_str30 filter_cat30 filter_code31 filter_str31 filter_cat31
//save "tempML.dta", replace
drop obs
by history_id: gen obs=_n // since we drop the multi will destory the structure of obs

// Create Ffilter: First used filter by this visitor 
by history_id: gen Ffilter=filter_cat1 if usef==1 & obs==1

// Create Sfilter: Second used filter by this visitor
by history_id: gen Sfilter=filter_cat1 if usef==1 & obs==2

// Create Tfilter: Third used filter
by history_id: gen Tfilter=filter_cat1 if usef==1 & obs==3

// fill in and modify filter variables
by history_id: replace Ffilter=Ffilter[_n-1] if Ffilter=="" 
gsort history_id -Sfilter
by history_id: replace Sfilter=Sfilter[_n-1] if Sfilter=="" 
gsort history_id -Tfilter
by history_id: replace Tfilter=Tfilter[_n-1] if Tfilter==""

by history_id: replace Ffilter="non" if Ffilter==""
replace Ffilter="price" if Ffilter=="price_up" | Ffilter=="price_down"
replace Ffilter="vintage" if Ffilter=="year_up" | Ffilter=="year_down"

by history_id: replace Sfilter="non" if Sfilter==""
replace Sfilter="price" if Sfilter=="price_up" | Sfilter=="price_down"
replace Sfilter="vintage" if Sfilter=="year_up" | Sfilter=="year_down"

by history_id: replace Tfilter="non" if Tfilter==""
replace Tfilter="price" if Tfilter=="price_up" | Tfilter=="price_down"
replace Tfilter="vintage" if Tfilter=="year_up" | Tfilter=="year_down"
*/

keep if obsss==1 // since we only need the unique visitor having thier independent variable
drop obsss winelist_code page_type url_code csuristem purchase ps his 
drop filter_code1 filter_str1 filter_cat1 filter_code2 filter_str2 filter_cat2 filter_code3 filter_str3 filter_cat3 filter_code4 filter_str4 filter_cat4 filter_code5 filter_str5 filter_cat5 filter_code6 filter_str6 filter_cat6 filter_code7 filter_str7 filter_cat7 filter_code8 filter_str8 filter_cat8 filter_code9 filter_str9 filter_cat9 filter_code10 filter_str10 filter_cat10 filter_code11 filter_str11 filter_cat11 filter_code12 filter_str12 filter_cat12 filter_code13 filter_str13 filter_cat13 filter_code14 filter_str14 filter_cat14 filter_code15 filter_str15 filter_cat15 filter_code16 filter_str16 filter_cat16 filter_code17 filter_str17 filter_cat17 filter_code18 filter_str18 filter_cat18 filter_code19 filter_str19 filter_cat19 filter_code20 filter_str20 filter_cat20 filter_code21 filter_str21 filter_cat21 filter_code22 filter_str22 filter_cat22 filter_code23 filter_str23 filter_cat23 filter_code24 filter_str24 filter_cat24 filter_code25 filter_str25 filter_cat25 filter_code26 filter_str26 filter_cat26 filter_code27 filter_str27 filter_cat27 filter_code28 filter_str28 filter_cat28 filter_code29 filter_str29 filter_cat29 filter_code30 filter_str30 filter_cat30 filter_code31 filter_str31 filter_cat31
replace reg_state=0 if reg_state==.

save "data_for_ML.dta", replace
