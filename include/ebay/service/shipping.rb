class Ebay  
  module ShoppingService
    def get_single_item(item_id)
      param = {
        'callname' => 'GetSingleItem',
        'version' => '1045',
        'appid' => @appname,
        'responseencoding' => 'JSON',
        'ItemID' => item_id.to_s,
        'IncludeSelector' => 'Details'
      }
      url = self.url_build 'open.api.ebay.com', '/shopping', param
      result = self.call url
      if result['Ack'] != 'Success' then
        puts 'エラーが発生しました'
        pp result
        return false
      end
      result
    end

    def get_shipping_costs(item_id)
      param = {
        'callname' => 'GetShippingCosts',
        'version' => '1045',
        'appid' => @appname,
        'responseencoding' => 'JSON',
        'ItemID' => item_id.to_s,
        'DestinationCountryCode' => 'JP',
        'DestinationPostalCode' => '95129'
      }
      url = self.url_build 'open.api.ebay.com', '/shopping', param
      result = self.call url
      if result['Ack'] != 'Success' then
        puts 'エラーが発生しました'
        pp result
        return false
      end
      result
    end
  end
end