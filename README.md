# 檔案說明
資料夾「data」為原始網站資料，裡面有 10 個檔案

## 瀏覽記錄相關
  * **00_wine_data_pageview**: 訪客頁面瀏覽紀錄，但不包含`page_type=='upload'`的紀錄。
  * **00_wine_data_filter_winelist**: 所有 wine_list 所使用到的 filter，可以使用 page_id 與瀏覽紀錄合併。
  
## 解碼瀏覽紀錄裡相對應的變數
  * **00_wine_nobot_refer**: refer_code
  * **00_wine_nobot_url**: url_code, winelist_code
  * **00_wine_nobot_emailbundle**: email_bundle
  * **00_wine_nobot_customerbundle**: customer_bundle
  
## 其他檔案
  * **icheers_trans**: 交易紀錄
  * **icheers_member**: 會員資料
  * **00_raw_wineinfo**: 每支酒的詳細資料
  
### 關於**00_wine_data_filter_winelist**內的 filter 有幾點說明
  1. 若`filter_code=='0' & filter_cat=='keywords'`: 表示訪客沒有使用關鍵字搜尋
