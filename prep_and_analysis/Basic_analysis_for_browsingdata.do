/*Date:20170425_data updated*/
/*Purpose: Basic Analysis and some summary statistics*/
clear all 
set more off
set maxvar 32767
capture log close
cd "/home/wine2/new_data_20170425/"  /*set the file location*/
use "00_wine_pageview_filter_member.dta" ,clear

sort visitor_id session_id date_time log_id
/* Calculate the unique visitors and visits */
by visitor_id: gen obs=_n
count if obs==1 // 667,068 is the # unique visitors

by visitor_id session_id: gen obss=_n
count if obss==1 // 1,348,855 is the actual # of visits(sessions)
// would be less than actual # since we combine some client into one visitor
/* Checking the composition of the visitors */
gsort visitor_id -session_id -date_time -log_id
gen member=1 if reg_state==1
by visitor_id: replace member=member[_n-1] if member==. //better way to defin member
count if member==1 & obs==1 // 2,524 is the # of members
count if purchase==1 & obs==1 // 3,268 is the # visitors purchasing the products
replace member=0 if member==.
replace purchase=0 if purchase==.
tab member purchase if obs==1

/* Composition of the page types */
tab page_type, sort

/* Check the active browser(or session) under our definition */
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


// Identify out the using-filter session
gen use_filter=1 if filter_cat1!=""
replace use_filter=0 if use_filter==. //use_filter means visitor do use filter at this session
by visitor_id session_id: egen tag_filter=max(use_filter)
by visitor_id session_id: gen useF=1 if tag_filter==1 // useF means do use filter in this session
replace useF=0 if useF==.
drop use_filte tag_filter

** Now we do the filter analysis considering non-choice as outside option
/* we should drop the inactive browsers */
drop if (short==1 | less==1| active==0) 
by visitor_id session_id: gen count=_n
by visitor_id session_id: keep if (useF==0 & count==1) | useF==1 
drop count
/*
sort visitor_id session_id date_time log_id
gen use_filter=1 if filter_cat1!=""
replace use_filter=0 if use_filter==.
by visitor_id session_id: egen tag_filter=max(use_filter) //tag_filter means visitor do use filter at this session
by visitor_id session_id: drop if tag_filter==0 
*/
/* Illustrate the graph of filter-usage among different induvudula's charc */
drop if filter_cat1=="" // since filter_cat1=="" means this visitor did not use filter, but now we dont care about "non-choice"
reshape long filter_cat filter_code filter_str, i(page_id) j(num)
drop if filter_cat==""
//drop if filter_cat=="" & (num==2 | num==3) 
gen filter_type=filter_cat
replace filter_type="price" if filter_type=="price_up" | filter_type=="price_down"
replace filter_type="vintage" if filter_type=="year_up" | filter_type=="year_down"
//replace filter_type="non-use" if filter_type=="" & useF==0 // since we consider only "non-choose in the session" as the non choose option
count if filter_type!="" // 2,166,382

/* Some visitor may choose the muti-first filter simultaneoustly, we chseck the ration */
drop if filter_type==""
sort visitor_id session_id date_time log_id num
by visitor_id: egen tag_multi= max(num) // tag_multi means the # of multi in this choice
gen multi =0
replace multi=1 if tag_multi>1 // multi means this visitor do choose the multi-first filter
drop obs // since obs already defined previously
by visitor_id: gen obs=_n // obs means the # od uniaue visitor
tab multi if obs==1 // 0: 146,015(89.41%) ; 1: 17,301(10.59%) ; Total: 163,316
//drop if multi==1

gen i=1
graph bar (percent) i, over(filter_type) title("Filter usage among whole unique visitors") ytitle("Percent") caption("Considering the outside option and active users") note("# of obs: 1,342,476")
//graph export "Whole-filter usage for active visitor.png", replace
drop i

** Now we consider the whole-filter usage instead of only the first one
use "00_wine_pageview_filter_member.dta" ,clear
sort visitor_id session_id date_time log_id
gen use_filter=1 if filter_cat1!=""
replace use_filter=0 if use_filter==.
by visitor_id session_id: egen tag_filter=max(use_filter) //tag_filter means visitor do use filter at this session
by visitor_id session_id: drop if tag_filter==0 
drop if filter_cat1=="" // since filter_cat1=="" means this visitor did not use filter, but now we dont care about "non-choice"
/* Illustrate the graph of filter-usage among different induvudula's charc */
drop csuristem wine_list buy tag_buy non_purchase use_filter tag_filter
compress // since reshape will lead the IO problem, we drop the redundant var and compress the file
reshape long filter_cat filter_code filter_str, i(page_id) j(num)
//save "3rd_reshaped_model.dta", replace // since the process of reshaping takes lots of time, we save the result
drop if filter_cat==""
gen filter_type=filter_cat
replace filter_type="price" if filter_type=="price_up" | filter_type=="price_down"
replace filter_type="vintage" if filter_type=="year_up" | filter_type=="year_down"
gen i=1
graph bar (percent) i , over(filter_type) title("Filter usage among whole unique visitors") ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs: 2,412,435")
//graph export "Whole-filter usage among unique visitors.png", replace
drop i

//illustrating the graph of filter-usage among whole visitors
gen member=1 if reg_status==1
gen non_member=1 if reg_status!=1
count if member==1 & filter_type!="" // 281,230
count if non_member==1 & filter_type!="" // 1,847,346
graph bar (percent) non_member member, over(filter_type)  title("Filter usage among whole unique visitors") legend(on order(1 "non-member" 2 "member" ) nostack) ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs in non-member: 292,244 ; # of obs in member: 2,120,191")
//graph export "Whole-filter usage vs member & non-member.png", replace

//illustrating the graph of filter-usage difference between gender
gen Male=1 if gender=="M"
gen Female=1 if gender=="F"
count if Male==1 & filter_type!="" // 232,097
count if Female==1 & filter_type!="" // 69,359
graph bar (percent) Male Female, over(filter_type) title("Filter usage among different gender")  legend(on order(1 "Male" 2 "Female" ) nostack) ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs: 288,468 ; # of obs in Male: 232,097 ; # of obs in Female: 69,359")
//graph export "Whole-filter usage vs different gender.png", replace

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
count if birthday!="" & filter_type!="" // 274,274
graph bar (percent) lower_than30 between_30_39 between_40_49 between_50_59 greater_than60, over(filter_type) title("Filter usage among different age group")  legend(on order(1 "<30" 2 "30~39" 3 "40~49" 4 "50~59" 5 ">60" ) nostack) ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs: 274,274")
//graph export "Whole-filter usage vs different age.png", replace

//illustrating the graph of filter-usage among different region group
count if county!="" & filter_type!="" // 300,676
gen North=1 if county== "臺北市" | county=="新北市"  | county=="桃園市"  | county=="新竹市"  | county=="新竹縣"  | county=="苗栗縣" | county=="基隆市" 
gen Mid=1 if county=="彰化縣" | county=="臺中市" | county=="南投縣" | county=="雲林縣" 
gen South=1 if county=="嘉義市" | county=="嘉義縣" | county=="臺南市" | county=="高雄市" | county=="屏東縣"
gen East=1 if county=="宜蘭縣" | county=="澎湖縣" | county=="臺東縣" | county=="花蓮縣" | county=="連江縣" | county=="金門縣"
graph bar (percent) North Mid South East, over(filter_type) title("Filter usage among different region group") legend(on order(1 "North" 2 "Mid" 3 "South" 4 "East") nostack) ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs: 313,509")
//graph export "Whole-filter usage vs different region.png", replace
/*
//illustrating the graph filter-usage among purchasing
count if purchase==1 & filter_type!="" // 330,676
count if non_purchase==1 & filter_type!="" // 1,827,900
graph bar (percent) non_purchase purchase, over(filter_type) title("Filter usage among purchase & non-purchase")  legend(on order(1 "non-purchase" 2 "purchase" ) nostack) ytitle("Percent") caption("Observation Level: Each visitor sho di use filter in his session") note("# of obs in non-purchase: 1,827,900 ; # of obs in purchase: 330,676")
//graph export "Whole-filter usage vs purchase & non-purchase.png", replace
*/
/*
* The graph in this part contains the "unknown" item 
gen UnknownG=1 if Male==. & Female==.
gen UnknownA=1 if age==.
gen UnknownR=1 if county==""
// filter usage among different gender & UnknowG
graph bar (percent) Male Female UnknownG , over(filter_type) title("Filter usage among different gender")  legend(on order(1 "Male" 2 "Female" 3 "Unknown") nostack  cols(3)) ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs: 2,128,576")
graph export "Whole-filter usage among gender & unknown.png", replace
// filter usage among different age & UnknownA
graph bar (percent) lower_than30 between_30_39 between_40_49 between_50_59 greater_than60  UnknownA, over(filter_type) title("Filter usage among different age group")  legend(on order(1 "<30" 2 "30~39" 3 "40~49" 4 "50~59" 5 ">60" 6 "unknown") nostack  ) ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs: 2,128,576")
graph export "Whole-filter usage among age & unknown.png", replace
// filter usage among different region & UnknownR
graph bar (percent) North Mid South East UnknownR , over(filter_type) title("Filter usage among different region")  legend(on order(1 "North" 2 "Mid" 3 "South" 4 "East" 5 "unknown") nostack  ) ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs: 2,128,576")
graph export "Whole-filter usage among region & unknown.png", replace
*/


// regression model 
drop if filter_type==""
gen grade=1 if filter_type=="grade"
gen grape=1 if filter_type=="grape"
gen keyword=1 if filter_type=="keyword"
gen price=1 if filter_type=="price"
gen region=1 if filter_type=="region"
gen reviewer=1 if filter_type=="reviewer" 
gen type=1 if filter_type=="type"
gen vintage=1 if filter_type=="vintage"
sort visitor_id session_id date_time log_id
by visitor_id: gen sumF= _N
by visitor_id: egen sumGrade= total(grade)
by visitor_id: egen sumGrape= total(grape)
by visitor_id: egen sumKeyword= total(keyword)
by visitor_id: egen sumPrice= total(price)
by visitor_id: egen sumRegion= total(region)
by visitor_id: egen sumReviewer= total(reviewer)
by visitor_id: egen sumType= total(type)
by visitor_id: egen sumVintage= total(vintage)
by visitor_id: gen Pgrade= sumGrade/sumF
by visitor_id: gen Pgrape= sumGrape/sumF
by visitor_id: gen Pkeyword= sumKeyword/sumF
by visitor_id: gen Pprice= sumPrice/sumF
by visitor_id: gen Pregion= sumRegion/sumF
by visitor_id: gen Previewer= sumReviewer/sumF
by visitor_id: gen Ptype= sumType/sumF
by visitor_id: gen Pvintage= sumVintage/sumF

replace member=0 if member==.
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

by visitor_id: gen obs=_n
count if obs==1 // 163,316 is the # unique visitors



global xlist member 
reg Pgrade $xlist if obs==1
est store m1
reg Pgrape $xlist if obs==1
est store m2
reg Pkeyword $xlist if obs==1
est store m3
reg Pprice $xlist if obs==1
est store m4
reg Pregion $xlist if obs==1
est store m5
reg Previewer $xlist if obs==1
est store m6
reg Ptype $xlist if obs==1
est store m7
reg Pvintage $xlist if obs==1
est store m8
esttab m1 m2 m3 m4 m5 m6 m7 m8 using reg_for_member.csv, se r2 ar2 replace


est clear
global xlist male age age2 North Mid South
reg Pgrade $xlist if obs==1
est store m1
reg Pgrape $xlist if obs==1
est store m2
reg Pkeyword $xlist if obs==1
est store m3
reg Pprice $xlist if obs==1
est store m4
reg Pregion $xlist if obs==1
est store m5
reg Previewer $xlist if obs==1
est store m6
reg Ptype $xlist if obs==1
est store m7
reg Pvintage $xlist if obs==1
est store m8
esttab m1 m2 m3 m4 m5 m6 m7 m8 using reg_for_charc2.csv, se r2 ar2 replace

* Combine all the independent variables
est clear
global xlist male lower_than30 between_30_39 between_40_49 between_50_59 greater_than60 North Mid South East
reg Pgrade $xlist if obs==1
est store m1
reg Pgrape $xlist if obs==1
est store m2
reg Pkeyword $xlist if obs==1
est store m3
reg Pprice $xlist if obs==1
est store m4
reg Pregion $xlist if obs==1
est store m5
reg Previewer $xlist if obs==1
est store m6
reg Ptype $xlist if obs==1
est store m7
reg Pvintage $xlist if obs==1
est store m8
esttab m1 m2 m3 m4 m5 m6 m7 m8 using reg_for_all_charc1.csv, se r2 ar2 replace

// Weighted regression model 
use "3rd_reshaped_model.dta", clear
drop if filter_cat==""
gen filter_type=filter_cat
replace filter_type="price" if filter_type=="price_up" | filter_type=="price_down"
replace filter_type="vintage" if filter_type=="year_up" | filter_type=="year_down"
gen i=1
graph bar (percent) i , over(filter_type) title("Filter usage among whole unique visitors") ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs: 2,412,435")
//graph export "Whole-filter usage among unique visitors.png", replace
drop i

//illustrating the graph of filter-usage among whole visitors
gen member=1 if reg_status==1
gen non_member=1 if reg_status!=1
count if member==1 & filter_type!="" // 281,230
count if non_member==1 & filter_type!="" // 1,847,346
graph bar (percent) non_member member, over(filter_type)  title("Filter usage among whole unique visitors") legend(on order(1 "non-member" 2 "member" ) nostack) ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs in non-member: 292,244 ; # of obs in member: 2,120,191")
//graph export "Whole-filter usage vs member & non-member.png", replace

//illustrating the graph of filter-usage difference between gender
gen Male=1 if gender=="M"
gen Female=1 if gender=="F"
count if Male==1 & filter_type!="" // 232,097
count if Female==1 & filter_type!="" // 69,359
graph bar (percent) Male Female, over(filter_type) title("Filter usage among different gender")  legend(on order(1 "Male" 2 "Female" ) nostack) ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs: 288,468 ; # of obs in Male: 232,097 ; # of obs in Female: 69,359")
//graph export "Whole-filter usage vs different gender.png", replace
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
count if birthday!="" & filter_type!="" // 274,274
graph bar (percent) lower_than30 between_30_39 between_40_49 between_50_59 greater_than60, over(filter_type) title("Filter usage among different age group")  legend(on order(1 "<30" 2 "30~39" 3 "40~49" 4 "50~59" 5 ">60" ) nostack) ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs: 274,274")
//graph export "Whole-filter usage vs different age.png", replace
//illustrating the graph of filter-usage among different region group
count if county!="" & filter_type!="" // 300,676
gen North=1 if county== "臺北市" | county=="新北市"  | county=="桃園市"  | county=="新竹市"  | county=="新竹縣"  | county=="苗栗縣" | county=="基隆市" 
gen Mid=1 if county=="彰化縣" | county=="臺中市" | county=="南投縣" | county=="雲林縣" 
gen South=1 if county=="嘉義市" | county=="嘉義縣" | county=="臺南市" | county=="高雄市" | county=="屏東縣"
gen East=1 if county=="宜蘭縣" | county=="澎湖縣" | county=="臺東縣" | county=="花蓮縣" | county=="連江縣" | county=="金門縣"
graph bar (percent) North Mid South East, over(filter_type) title("Filter usage among different region group") legend(on order(1 "North" 2 "Mid" 3 "South" 4 "East") nostack) ytitle("Percent") caption("Observation Level: Each visitor's used filter") note("# of obs: 313,509")
//graph export "Whole-filter usage vs different region.png", replace

// weighted regression model 
drop if filter_type==""
sort visitor_id session_id date_time log_id
by visitor_id session_id: egen sumf= rank(-log_id)
by visitor_id: egen sumF= total(sumf)
by visitor_id: egen Grade= total(sumf) if filter_type=="grade"
by visitor_id: egen Grape= total(sumf) if filter_type=="grape"
by visitor_id: egen Keyword= total(sumf) if filter_type=="keyword"
by visitor_id: egen Price= total(sumf) if filter_type=="price"
by visitor_id: egen Region= total(sumf) if filter_type=="region"
by visitor_id: egen Reviewer= total(sumf) if filter_type=="reviewer"
by visitor_id: egen Type= total(sumf) if filter_type=="type"
by visitor_id: egen Vintage= total(sumf) if filter_type=="vintage"

foreach var of varlist Grade Grape Keyword Price Region Reviewer Type Vintage {
 by visitor_id: gen P`var'= `var'/sumF 
}
foreach var of varlist PGrade PGrape PKeyword PPrice PRegion PReviewer PType PVintage {
 gsort visitor_id -`var'
 by visitor_id: replace `var'=`var'[_n-1] if `var'==. & _n!=1
 replace `var'=0 if `var'==.
}
replace member=0 if member==.
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

by visitor_id: gen obs=_n
count if obs==1 // 163,316 is the # unique visitors

global xlist member 
reg PGrade $xlist if obs==1
est store m1
reg PGrape $xlist if obs==1
est store m2
reg PKeyword $xlist if obs==1
est store m3
reg PPrice $xlist if obs==1
est store m4
reg PRegion $xlist if obs==1
est store m5
reg PReviewer $xlist if obs==1
est store m6
reg PType $xlist if obs==1
est store m7
reg PVintage $xlist if obs==1
est store m8
esttab m1 m2 m3 m4 m5 m6 m7 m8 using wreg_for_all_member.csv, se r2 ar2 replace

est clear
global xlist male age age2 North Mid South
reg PGrade $xlist if obs==1
est store m1
reg PGrape $xlist if obs==1
est store m2
reg PKeyword $xlist if obs==1
est store m3
reg PPrice $xlist if obs==1
est store m4
reg PRegion $xlist if obs==1
est store m5
reg PReviewer $xlist if obs==1
est store m6
reg PType $xlist if obs==1
est store m7
reg PVintage $xlist if obs==1
est store m8
esttab m1 m2 m3 m4 m5 m6 m7 m8 using wreg_for_charc2.csv, se r2 ar2 replace

* Combine all the independent variables
est clear
global xlist male lower_than30 between_30_39 between_40_49 between_50_59 greater_than60 North Mid South East
reg PGrade $xlist if obs==1
est store m1
reg PGrape $xlist if obs==1
est store m2
reg PKeyword $xlist if obs==1
est store m3
reg PPrice $xlist if obs==1
est store m4
reg PRegion $xlist if obs==1
est store m5
reg PReviewer $xlist if obs==1
est store m6
reg PType $xlist if obs==1
est store m7
reg PVintage $xlist if obs==1
est store m8
esttab m1 m2 m3 m4 m5 m6 m7 m8 using reg_for_all_charc1.csv, se r2 ar2 replace


// Weighted regression model 2
use "3rd_model.dta", clear
drop if filter_cat==""
gen filter_type=filter_cat
replace filter_type="price" if filter_type=="price_up" | filter_type=="price_down"
replace filter_type="vintage" if filter_type=="year_up" | filter_type=="year_down"
gen member=1 if reg_status==1
gen non_member=1 if reg_status!=1
count if member==1 & filter_type!="" // 281,230
count if non_member==1 & filter_type!="" // 1,847,346
gen Male=1 if gender=="M"
gen Female=1 if gender=="F"
count if Male==1 & filter_type!="" // 232,097
count if Female==1 & filter_type!="" // 69,359
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
count if birthday!="" & filter_type!="" // 274,274
count if county!="" & filter_type!="" // 300,676
gen North=1 if county== "臺北市" | county=="新北市"  | county=="桃園市"  | county=="新竹市"  | county=="新竹縣"  | county=="苗栗縣" | county=="基隆市" 
gen Mid=1 if county=="彰化縣" | county=="臺中市" | county=="南投縣" | county=="雲林縣" 
gen South=1 if county=="嘉義市" | county=="嘉義縣" | county=="臺南市" | county=="高雄市" | county=="屏東縣"
gen East=1 if county=="宜蘭縣" | county=="澎湖縣" | county=="臺東縣" | county=="花蓮縣" | county=="連江縣" | county=="金門縣"

// weighted regression model 2
drop if filter_type==""
sort visitor_id session_id date_time log_id

by visitor_id session_id: egen ord= rank(-log_id) 
by visitor_id session_id: egen deno= total(ord) // deno here is the weight of this session
by visitor_id session_id: gen prob= ord/deno // prob here is the probability of using this filter in this session  
by visitor_id: egen Deno=total(prob) // Deno here is the weight of visitor's whole session
by visitor_id: egen Grade= total(prob) if filter_type=="grade"
by visitor_id: egen Grape= total(prob) if filter_type=="grape"
by visitor_id: egen Keyword= total(prob) if filter_type=="keyword"
by visitor_id: egen Price= total(prob) if filter_type=="price"
by visitor_id: egen Region= total(prob) if filter_type=="region"
by visitor_id: egen Reviewer= total(prob) if filter_type=="reviewer"
by visitor_id: egen Type= total(prob) if filter_type=="type"
by visitor_id: egen Vintage= total(prob) if filter_type=="vintage"
foreach var of varlist Grade Grape Keyword Price Region Reviewer Type Vintage {
 by visitor_id: gen P`var'= `var'/Deno
}
foreach var of varlist PGrade PGrape PKeyword PPrice PRegion PReviewer PType PVintage {
 gsort visitor_id -`var'
 by visitor_id: replace `var'=`var'[_n-1] if `var'==. & _n!=1
 replace `var'=0 if `var'==.
}
replace member=0 if member==.
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

by visitor_id: gen obs=_n
count if obs==1 // 163,316 is the # unique visitors

global xlist member 
reg PGrade $xlist if obs==1
est store m1
reg PGrape $xlist if obs==1
est store m2
reg PKeyword $xlist if obs==1
est store m3
reg PPrice $xlist if obs==1
est store m4
reg PRegion $xlist if obs==1
est store m5
reg PReviewer $xlist if obs==1
est store m6
reg PType $xlist if obs==1
est store m7
reg PVintage $xlist if obs==1
est store m8
esttab m1 m2 m3 m4 m5 m6 m7 m8 using wreg2_for_all_member.csv, se r2 ar2 replace

est clear
global xlist male age age2 North Mid South
reg PGrade $xlist if obs==1
est store m1
reg PGrape $xlist if obs==1
est store m2
reg PKeyword $xlist if obs==1
est store m3
reg PPrice $xlist if obs==1
est store m4
reg PRegion $xlist if obs==1
est store m5
reg PReviewer $xlist if obs==1
est store m6
reg PType $xlist if obs==1
est store m7
reg PVintage $xlist if obs==1
est store m8
esttab m1 m2 m3 m4 m5 m6 m7 m8 using wreg2_for_charc2.csv, se r2 ar2 replace
