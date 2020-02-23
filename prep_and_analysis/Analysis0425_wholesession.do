clear all 
set more off
set maxvar 32767
capture log close
cd "/home/wine2/new_data_20170425/"  /*set the file location*/

/*---capture the session that visitor do use the filter in the browsing_data---*/
use "00_wine_pageview_filter_member.dta" ,clear
sort visitor_id session_id date_time log_id
by visitor_id session_id: gen obss=_n
count if obss==1 // 1,348,855 is the # of visits(sessions)

// Identify out the active session
gen tag_d=1 if page_type=="wine_detail"
replace tag_d=0 if tag_d==.
sort visitor_id session_id date_time log_id
by visitor_id session_id: egen tagD= max(tag_d)
by visitor_id session_id: gen active=1 if tagD==1 
replace active=0 if active==.
by visitor_id session_id: gen unactive=1 if tagD==0
drop tag_d tagD
tab active if obss==1 // active session is 40.25%

// Identify out viewed pages in the session
by visitor_id session_id: gen count=_n
by visitor_id session_id: egen pages= max(count)
drop count
tab pages if obss==1
summarize pages if obss==1, detail // since the histo is ugly. we merely do it.
histogram pages if obss==1, discrete percent lwidth(thick) title("Distribution of Viewed Page")
//graph export "Distribution of Viewed Page.png", replace
by visitor_id session_id: gen less=1 if pages<5 // we define browsed pages less than 5 is less
replace less=0 if less==.

// Identify out the browsing time for each session 
by visitor_id session_id: gen duration= date_time[_N]-date_time[1] if pages>1
replace duration= duration/1000 // since the unit of original duration is milliseconds
tab duration if obss==1
summarize duration if obss==1
histogram duration if obss==1, discrete percent lwidth(thick) xtitle(Duration(sec)) title("Distribution of Duration")
//graph export "Distribution of Duration.png", replace
by visitor_id session_id: gen short=1 if duration<300 | duration==.  // we define browsing time less than 5min is too short
replace short=0 if short==.
//drop if less==1 | short==1

sort visitor_id session_id date_time log_id
gen use_filter=1 if filter_cat1!=""
replace use_filter=0 if use_filter==. //use_filter means visitor do use filter at this timing
by visitor_id session_id: egen tag_filter=max(use_filter) //tag_filter means visitor do use filter in whole session
by visitor_id session_id: gen obs=_n if filter_cat1!="" & tag_filter==1
by visitor_id session_id: egen tag_first=min(obs) if filter_cat1!="" & tag_filter==1
by visitor_id session_id: gen firstuse=1 if obs==tag_first & filter_cat1!="" & tag_filter==1
// firstuse means the first-timing of using filter in this session
by visitor_id session_id: gen Obs=_n if tag_filter==0
keep if (tag_filter==1 & firstuse==1) | (tag_filter==0 & Obs==1)
/*----------------Illustrate the graph of filter-usage among different induvudula's charc-----------------------*/
drop if filter_cat1=="" // since filter_cat1=="" means this visitor did not use filter, but now we dont care about "non-choice"
reshape long filter_code filter_cat filter_str, i(page_id) j(num)
drop if filter_cat=="" 
count if filter_cat!="" // 496,673
gen filter_type=filter_cat
replace filter_type="price" if filter_type=="price_up" | filter_type=="price_down"
replace filter_type="vintage" if filter_type=="year_up" | filter_type=="year_down" 
//replace filter_type="non-use" if filter_type==""

/* Some visitor may choose the muti-first filter simultaneoustly, we chseck the ration */
drop if filter_type==""
sort visitor_id session_id date_time log_id num
by visitor_id session: egen tag_multi= max(num) // tag_multi means the # of multi in this choice
gen multi =0
replace multi=1 if tag_multi>1 // multi means this visitor do choose the multi-first filter
drop obs
by visitor_id session_id: gen obs=_n // obs means the # od uniaue visitor
tab multi if obs==1
//drop if multi==1


gen i=1
graph bar (percent) i if multi==0, over(filter_type) title("First-Filter usage among whole unique visitors") ytitle("Percent") caption("Observation level: First-filter for each visitor's session") note("# of obs: 296,255")
//graph export "Whole-First-Filter usage among unique visitors.png", replace
drop i

//illustrating the graph of filter-usage among whole visitors
gen member=1 if reg_status==1
replace member=0 if member==.
gen non_member=1 if reg_status!=1
count if member==1 & filter_type!="" & multi==0 //29,658
count if non_member==1 & filter_type!="" & multi==0 //266,597
/*label var member "member or non-member"
label define member_lb 0"non-member" 1"member"
label values member member_lb //In this step, we label the numeric value in member var
//illustrating the graph of filter-usare difference between member & non-member*/
graph bar (percent) non_member member if multi==0, over(filter_type) title("First-Filter usage among member & non-member") title("Observation level: First-filter for each visitor's session") legend(on order(1 "non-member" 2 "member" ) nostack) ytitle("Percent") caption("First session for each visitor") note("# of obs in non-member: 266,597 ; # of obs in member: 29,658")
//graph export "Whole-First-filter usage vs member & non-member.png", replace

//illustrating the graph of filter-usage difference between gender
gen Male=1 if gender=="M"
gen Female=1 if gender=="F"
count if Male==1 & filter_type!="" & multi==0 //23,313
count if Female==1 & filter_type!="" & multi==0 //7,328
graph bar (percent) Male Female if multi==0, over(filter_type) title("First-Filter usage among different gender")  legend(on order(1 "Male" 2 "Female" ) nostack) ytitle("Percent") caption("Observation level: First-filter for each visitor's session") note("# of obs: 7,350 ; # of obs in Male: 23,313 ; # of obs in Female: 7,328")
//graph export "Whole-First-filter usage vs different gender.png", replace

//illustrating the graph of filter-usage among different age group
gen datetime=dofc(date_time)
gen year= year(datetime)
gen Byear= substr(birthday,1,4)
destring Byear, replace
gen age= year-Byear
gen lower_than30=1 if age<30
gen between_30_39=1 if age>=30 & age<=39 
gen between_40_49=1 if age>=40 & age<=49
gen between_50_59=1 if age>=50 & age<=59
gen greater_than60=1 if age>=60 & age!=.
count if birthday!="" & filter_type!="" & multi==0 //
graph bar (percent) lower_than30 between_30_39 between_40_49 between_50_59 greater_than60 if multi==0, over(filter_type) title("First-Filter usage among different age group")  legend(on order(1 "<30" 2 "30~39" 3 "40~49" 4 "50~59" 5 ">60" ) nostack) ytitle("Percent") caption("Observation level: First-filter for each visitor's session") note("# of obs: 27,722")
//graph export "Whole-First-filter usage vs different age.png", replace

//illustrating the graph of filter-usage among different region group
count if county!="" & filter_type!="" & multi==0 //32,012
gen North=1 if county== "臺北市" | county=="新北市"  | county=="桃園市"  | county=="新竹市"  | county=="新竹縣"  | county=="苗栗縣" | county=="基隆市" 
gen Mid=1 if county=="彰化縣" | county=="臺中市" | county=="南投縣" | county=="雲林縣" 
gen South=1 if  county=="嘉義市" | county=="嘉義縣" | county=="臺南市" | county=="高雄市" | county=="屏東縣"
gen East=1 if  county=="宜蘭縣" | county=="澎湖縣" | county=="臺東縣" | county=="花蓮縣" | county=="連江縣" | county=="金門縣"
graph bar (percent) North Mid South East if multi==0, over(filter_type) title("First-Filter usage among different region group") legend(on order(1 "North" 2 "Mid" 3 "South" 4 "East") nostack) ytitle("Percent") caption("Observation level: First-filter for each visitor's session") note("# of obs: 32,012")
//graph export "Whole-First-filter usage vs different region.png", replace
/*
//illustrating the graph filter-usage among purchasing
count if purchase==1 & filter_type!="" & multi==0 //44,101
count if non_purchase==1 & filter_type!="" //398,960
graph bar (percent) non_purchase purchase if multi==0, over(filter_type) title("First-Filter usage among purchase & non-purchase") title("First-Filter usage among whole unique visitors") legend(on order(1 "non-purchase" 2 "purchase" ) nostack) ytitle("Percent") caption("Whole-First session for each visitor") note("# of obs in non-purchase: 398,960 ; # of obs in purchase: 44,101")
graph export "Whole-First-filter usage vs purchase & non-purchase.png", replace
*/

** Preparation for mlogit
gen y=1 if filter_type=="grade"
replace y=2 if filter_type=="grape"
replace y=3 if filter_type=="keyword"
replace y=4 if filter_type=="price"
replace y=5 if filter_type=="region"
replace y=6 if filter_type=="reviewer"
replace y=7 if filter_type=="type"
replace y=8 if filter_type=="vintage"
label var y "filter_type" 
label define y_lb1 1"grade" 2"grape" 3"keyword" 4"price" 5"region" 6"reviewer" 7"type" 8"vintage"
label values y y_lb1
replace lower_than30=0 if lower_than30==. & age!=.
replace between_30_39=0 if between_30_39==. & age!=.
replace between_40_49=0 if between_40_49==. & age!=.
replace between_50_59=0 if between_50_59==. & age!=.
replace greater_than60=0 if greater_than60==. & age!=.
replace North=0 if North==. & county!=""
replace Mid=0 if Mid==. & county!=""
replace South=0 if South==. & county!=""
replace East=0 if East==. & county!=""
gen male=1 if gender=="M"
replace male=0 if gender=="F" // since the var of gender we define previously is different
gen age2= age^2





// Multinomial Logit under clustered observation
global ylist y
global xlist member 
mlogit $ylist $xlist if multi==0, cluster(visitor_id) 
mfx, predict(pr outcome(1))
mfx, predict(pr outcome(2))
mfx, predict(pr outcome(3))
mfx, predict(pr outcome(4))
mfx, predict(pr outcome(5))
mfx, predict(pr outcome(6))
mfx, predict(pr outcome(7))
mfx, predict(pr outcome(8))


* combine all the the other charc. independent variables
global ylist y
global xlist male lower_than30 between_30_39 between_40_49 between_50_59 greater_than60 North Mid South East
mlogit $ylist $xlist if multi==0, cluster(visitor_id) // variance matrix is highly singular
mfx, predict(pr outcome(1))
mfx, predict(pr outcome(2))
mfx, predict(pr outcome(3))
mfx, predict(pr outcome(4))
mfx, predict(pr outcome(5))
mfx, predict(pr outcome(6))
mfx, predict(pr outcome(7))
mfx, predict(pr outcome(8))


global ylist y
global xlist male age age2 North Mid South East
mlogit $ylist $xlist if multi==0, cluster(visitor_id)
mfx, predict(pr outcome(1))
mfx, predict(pr outcome(2))
mfx, predict(pr outcome(3))
mfx, predict(pr outcome(4))
mfx, predict(pr outcome(5))
mfx, predict(pr outcome(6))
mfx, predict(pr outcome(7))
mfx, predict(pr outcome(8))

