/*Date:20170819*/
/*Purpose: ML analysis*/
clear all 
set more off
//set maxvar 32767
capture log close
cd "/home/wine2/new_data_20170425/"  /*set the file location*/

use "00_wine_pageview_filter_member.dta" ,clear
drop wine_list buy tag_buy non_purchase client_id customerid
// first drop the variables which are redundant to the analysis, could be changed
sort visitor_id session_id date_time log_id
by visitor_id: gen obs=_n // identify out the unique visitors
count if obs==1 // 667,068 is the # unique visitors

/* Create the independent variables */
// Create the DP: time duration per visit for each unique visitor
sort visitor_id session_id date_time log_id
by visitor_id session_id: gen duration= date_time[_N]-date_time[1] // duration is for session
replace duration= duration/1000 // since the unit is millisecond
by visitor_id session_id:gen obss=_n // obss is the # of transaction in each session
by visitor_id : egen DP=mean(duration) if obss==1 
by visitor_id: replace DP=DP[_n-1] if DP==. & _n!=1 // fill in the missing value, can do it later

// Create the VP: viewed-pages per visit
sort visitor_id session_id date_time log_id
by visitor_id session_id: gen pages= _N
by visitor_id: egen VP=mean(pages) if obss==1
by visitor_id: replace VP=VP[_n-1] if VP==. & _n!=1 // fill in the missing value, can do it later

// Create page-type per visit
// Create MPP: main pages per visit
gen tag_mainpage=1 if page_type=="main_wine"
replace tag_mainpage=0 if tag_mainpage==.
by visitor_id: egen mpage=total(tag_mainpage)
by visitor_id session_id, sort: gen ness = _n ==1
by visitor_id: replace ness = sum(ness)
by visitor_id: replace ness = ness[_N] // ness mans # of session for each unique visitor
by visitor_id: gen MPP= mpage/ ness
drop tag_mainpage mpage

// Create WLP: wine-list per visit
gen tag_winelist=1 if page_type=="list_wine"
replace tag_winelist=0 if tag_winelist==.
by visitor_id: egen mwlist=total(tag_winelist)
by visitor_id: gen WLP= mwlist/ ness
drop tag_winelist mwlist

// Create WDP: wine-detail per visit
gen tag_winedetail=1 if page_type=="wine_detail"
replace tag_winedetail=0 if tag_winedetail==.
by visitor_id: egen mwdetail=total(tag_winedetail)
by visitor_id: gen WDP= mwdetail/ ness
drop tag_winedetail mwdetail

// Create WIP: winery-intro per visit
gen tag_wineryintro=1 if page_type=="winery_intro"
replace tag_wineryintro=0 if tag_wineryintro==.
by visitor_id: egen mwintro=total(tag_wineryintro)
by visitor_id: gen WIP= mwintro/ ness
drop tag_wineryintro mwintro

// Create Member: whether the visitor is a member
gen member=1 if reg_status==1
replace member=0 if member==.


/* Revise the Y dependent variable: purchase*/
replace purchase=0 if purchase==.

/// To create the X as the info. of using filter
gen tag_usef=1 if filter_cat1!="" // tag_usef means visitor do use filter at this timing
by visitor_id: egen sumtagf=total(tag_usef)
by visitor_id: gen usef=1 if sumtagf>0 // usef means this visitor do use the filter among his visiting sessions
replace usef=0 if usef==.
keep if (usef==0 & obs==1) | (usef==1 & tag_usef==1) // to let reshape-process be quickly, we drop redundant visitor who do not use filter in his whole session
drop obs // since the previous process will broke the sturcture of obs
by visitor_id: gen obs=_n
by visitor_id: keep if obs<=3 // for the visitor who use visitor, if his obs!=1&2&3, then it is not the first timing of using filter
by visitor_id: gen multi=1 if filter_cat2!="" & usef==1
replace multi=0 if multi==. & usef==1
tab multi if obs==1 & usef==1
drop if multi==1 // since the ratio of multi-choice is low, we drop it.
drop multi tag_usef sumtagf
drop filter_code2 filter_str2 filter_cat2 filter_code3 filter_str3 filter_cat3 filter_code4 filter_str4 filter_cat4 filter_code5 filter_str5 filter_cat5 filter_code6 filter_str6 filter_cat6 filter_code7 filter_str7 filter_cat7 filter_code8 filter_str8 filter_cat8 filter_code9 filter_str9 filter_cat9 filter_code10 filter_str10 filter_cat10 filter_code11 filter_str11 filter_cat11 filter_code12 filter_str12 filter_cat12 filter_code13 filter_str13 filter_cat13 filter_code14 filter_str14 filter_cat14 filter_code15 filter_str15 filter_cat15 filter_code16 filter_str16 filter_cat16 filter_code17 filter_str17 filter_cat17 filter_code18 filter_str18 filter_cat18 filter_code19 filter_str19 filter_cat19 filter_code20 filter_str20 filter_cat20 filter_code21 filter_str21 filter_cat21 filter_code22 filter_str22 filter_cat22 filter_code23 filter_str23 filter_cat23 filter_code24 filter_str24 filter_cat24 filter_code25 filter_str25 filter_cat25 filter_code26 filter_str26 filter_cat26 filter_code27 filter_str27 filter_cat27 filter_code28 filter_str28 filter_cat28 filter_code29 filter_str29 filter_cat29 filter_code30 filter_str30 filter_cat30 filter_code31 filter_str31 filter_cat31
//save "tempML.dta", replace
drop obs
by visitor_id: gen obs=_n // since we drop the multi will destory the structure of obs

// Create Ffilter: First used filter by this visitor 
by visitor_id: gen Ffilter=filter_cat1 if usef==1 & obs==1

// Create Sfilter: Second used filter by this visitor
by visitor_id: gen Sfilter=filter_cat1 if usef==1 & obs==2

// Create Tfilter: Third used filter
by visitor_id: gen Tfilter=filter_cat1 if usef==1 & obs==3

// fill in and modify filter variables
by visitor_id: replace Ffilter=Ffilter[_n-1] if Ffilter=="" 
gsort visitor_id -Sfilter
by visitor_id: replace Sfilter=Sfilter[_n-1] if Sfilter=="" 
gsort visitor_id -Tfilter
by visitor_id: replace Tfilter=Tfilter[_n-1] if Tfilter==""

by visitor_id: replace Ffilter="non" if Ffilter==""
replace Ffilter="price" if Ffilter=="price_up" | Ffilter=="price_down"
replace Ffilter="vintage" if Ffilter=="year_up" | Ffilter=="year_down"

by visitor_id: replace Sfilter="non" if Sfilter==""
replace Sfilter="price" if Sfilter=="price_up" | Sfilter=="price_down"
replace Sfilter="vintage" if Sfilter=="year_up" | Sfilter=="year_down"

by visitor_id: replace Tfilter="non" if Tfilter==""
replace Tfilter="price" if Tfilter=="price_up" | Tfilter=="price_down"
replace Tfilter="vintage" if Tfilter=="year_up" | Tfilter=="year_down"


keep if obs==1 // since we only need the unique visitor having thier independent variable
drop obs usef
save "data_for_ML.dta", replace



