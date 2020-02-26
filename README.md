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
  2. 若 `filter_code=='-1' (& filter_cat=='price_up' | filter_cat=='price_down')`: 表示訪客沒有設定價格上限或下限
  3. 若 `filter_code == "vn" & (filter_cat == "year_up" | filter_cat == "year_down")` : 表示訪客沒有設定年份上限或下限
  4. 若多個 winelist 來自相同 client_id 且瀏覽時間很近，且這些 winelist 所使用的 filter_cat, filter_code 幾乎相同，差別只在 `filter_cat == webpage` 或 sortpattern 或 numbersofwine 不同，則這些 winelist 很可能是同一次搜尋行為，但訪客改變排序；或者清單太長，網站將清單分割成多頁；或者訪客改變每一頁顯示的酒款數量。
  例子一：以下四筆資料可能只使用「一次」 filter，但瀏覽多個頁面或改變清單排序方式
   * `page_id == 2031701, 2031734`(只有 sortpattern 不同)
   * `page_id == 2031701, 2031773, 2031813` (只有 webpage 不同)
