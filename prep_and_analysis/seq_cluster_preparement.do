/*Date:20171025*/
/*Purpose: preparement for k-means*/
clear all 
set more off
//set maxvar 32767
capture log close
cd "/home/wine2/new_data_20170425/"  /*set the file location*/

use "00_wine_pageview_filter_member.dta" ,clear

/*Do the hisitory_id process*/
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
replace duration=duration/14400000 // now the unit of duration is day
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
tab Mon if order==1 & obsss==1 // tab the distribution so as to know most transaction is completed in a month.
histogram Mon if obsss==1 & order==1, bin(21) percent // grid line, e.rose bar, dim-gray background, Large title, no outline 


// Also, too long month record is useless for the firms to predict
by history_id: drop if mon>2 & order==0
by history_id: keep if order==0 | (mon==Mon & order==1) | (mon==Mon-1 & order==1)
drop dur duration obss visit DP obsss pages VP datetime month
/********** Now all the history_id is a month record history ******************/


keep history_id page_type order
replace page_type="spirit" if strpos(page_type, "spirit")
replace page_type="topic" if inlist(page_type, "topic_a", "topic_a1", "topic_b", ///
"topic_b1", "topic_c", "topic_c1")
drop if inlist(page_type, "no_head", "admin", "long_tail")
replace page_type="cart3" if strpos(page_type, "cart3")
replace page_type="cart1" if strpos(page_type, "cart1")
replace page_type="info" if inlist(page_type, "newbie", "garentee")

/*
// percentage of page_type for each history_id
bysort history_id: gen Npage=_N
foreach name in main_wine list_wine wine_detail ///
topic wine_recommend info{
gen `name'=1 if page_type=="`name'"
  foreach var in `name'{
  bysort history_id: egen N`var'=total(`var')
  bysort history_id: gen P`var'= N`var'/Npage
  bysort history_id: replace P`var'= P`var'
  drop `var' N`var' 
}
}
drop Npage 

// keep only one history_id since we've filled in the #pages information
bysort history_id: gen obs=_n
keep if obs==1
drop obs page_type
*/


//keep if history_id <= 100000
//keep if order==1
//drop order
//keep if inlist(page_type, "list_wine", "wine_detail", "main_wine")
bysort history_id: gen j=_n
bysort history_id: gen obs=_N
tab obs order if j==1 // most of the obs is less than 1000
summarize(obs) if order==1 & j==1
histogram obs if j==1 & order==1, bin(1592) percent // grid line, e.rose bar, dim-gray background, Large title, no outline 

drop if (obs<2&order==0) | (j>1000&order==0)
drop order obs j
keep if inlist(page_type, "list_wine", "wine_detail", "main_wine")
bysort history_id: gen j=_n // the j here is for reshape

save "data_for_seq_cluster.dta", replace

/*
/* seq cluster for the order sent history */
clear all 
set more off
//set maxvar 32767
capture log close
cd "/home/wine2/new_data_20170425/"  /*set the file location*/

use "00_wine_pageview_filter_member.dta" ,clear

/*Do the hisitory_id process*/
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
// history_id is the record for each purchase-history
// Create order: whether the order sent in this history
bysort history_id: egen tag_order=max(ps)
bysort history_id: gen order=1 if tag_order!=0
replace order=0 if order==.
drop tag_order


keep history_id page_type order
replace page_type="spirit" if strpos(page_type, "spirit")
replace page_type="topic" if inlist(page_type, "topic_a", "topic_a1", "topic_b", ///
"topic_b1", "topic_c", "topic_c1")
drop if inlist(page_type, "no_head", "admin", "long_tail")
replace page_type="cart3" if strpos(page_type, "cart3")
replace page_type="cart1" if strpos(page_type, "cart1")
replace page_type="info" if inlist(page_type, "newbie", "garentee")

drop if inlist(page_type, "spirit", )

keep if order==1
drop order
bysort history_id: gen j=_n // the j here is for reshape

save "data_for_seq_cluster_order.dta", replace

