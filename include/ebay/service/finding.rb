class Ebay
  module FindingService
    def find_items_advanced(category_id, entries_per_page, page_number, min_price, max_price=nil)
      param = {
        'OPERATION-NAME' => 'findItemsAdvanced',
        'SERVICE-VERSION' => '1.0.0',
        'SECURITY-APPNAME' => @appname,
        'RESPONSE-DATA-FORMAT' => 'JSON',
        'REST-PAYLOAD' => 'true',
        'paginationInput.entriesPerPage' => entries_per_page.to_s,
        'paginationInput.pageNumber' => page_number,
        'itemFilter(0).name' => 'LocatedIn',
        'itemFilter(0).value' => 'JP',
        'itemFilter(1).name' => 'MinPrice',
        'itemFilter(1).value' => min_price.to_s,
        'itemFilter(1).paramName' => 'Currency',
        'itemFilter(1).paramValue' => 'CNY'
      }
      if max_price then
        param.merge!({
          'itemFilter(2).name' => 'MaxPrice',
          'itemFilter(2).value' => max_price.to_s,
          'itemFilter(2).paramName' => 'Currency',
          'itemFilter(2).paramValue' => 'CNY'
        })
      end
      param.merge!({
        'categoryId' => category_id.to_s,
        'outputSelector(0)' => 'PictureURLSuperSize',
        'outputSelector(1)' => 'SellerInfo'
      })
      url = self.url_build 'svcs.ebay.com', '/services/search/FindingService/v1', param
      
      result = self.call url
      if result['findItemsAdvancedResponse'][0]['ack'][0] != 'Success' then
        puts 'エラーが発生しました'
        pp result
        return false
      end
      result
    end
  
    def all_items_count_by_cat(category_id)
      url = self.url_build('svcs.ebay.com', '/services/search/FindingService/v1', {
        'OPERATION-NAME' => 'findItemsAdvanced',
        'SERVICE-VERSION' => '1.0.0',
        'SECURITY-APPNAME' => @appname,
        'RESPONSE-DATA-FORMAT' => 'JSON',
        'REST-PAYLOAD' => 'true',
        'paginationInput.entriesPerPage' => '1',
        'itemFilter(0).name' => 'LocatedIn',
        'itemFilter(0).value' => 'JP',
        'categoryId' => category_id.to_s
      })
      result = self.call url
      if result['findItemsAdvancedResponse'][0]['ack'][0] != 'Success' then
        puts 'エラーが発生しました'
        pp result
        exit
      end
      result['findItemsAdvancedResponse'][0]['paginationOutput'][0]['totalEntries'][0].to_i
    end
  end
end