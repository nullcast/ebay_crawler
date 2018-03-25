require 'bundler/setup'
require 'nokogiri'
require 'open-uri'
require 'active_record'
require 'activerecord-import/base'

require_relative '../models/product'
require_relative '../models/seller'

require 'dotenv'
Dotenv.load File.expand_path('../../config/.env', __FILE__)

require 'sidekiq'
Sidekiq.configure_server do |config|
  config.redis = { url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}"}
end
Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}" }
end

require_relative '../include/ebay/ebay'
$ebay = Ebay.new(ENV['EBAY_APP_KEY'])
$ebay.extend(Ebay::FindingService)
$ebay.extend(Ebay::ShoppingService)

class Crawler
  include Sidekiq::Worker
  sidekiq_options queue: :crawler

  def perform(data)
    p_insert = []
    p_update = []
    s_insert = Set.new
    
    items =  data['findItemsAdvancedResponse'][0]['searchResult'][0]['item']
    items.each do |i|
      if Product::check_product i['itemId'][0], i['viewItemURL'][0] then
        p_update << {item_id: i['itemId'][0], view_item_url: i['viewItemURL'][0]}
      else
        selling_status = i['sellingStatus'][0]
        shipping_info = i['shippingInfo'][0]
        listing_info = i['listingInfo'][0]
        product = Product.new(
          itemId: i['itemId'][0],
          title: i['title'][0],
          primaryCategory: i['primaryCategory'][0]['categoryName'][0],
          secondaryCategory: i['secondaryCategory'] ? i['secondaryCategory'][0]['categoryName'][0] : nil,
          price: selling_status['currentPrice'][0]['__value__'],
          shippingInfo: shipping_info['shippingType'][0],
          shippingFee: shipping_info['shippingServiceCost']?shipping_info['shippingServiceCost'][0]['__value__']:0,
          shippingServiceName: false,
          itemStartDate: Time.parse(listing_info['startTime'][0]).strftime('%Y-%m-%d %H:%M:%S'),
          itemEndDate: Time.parse(listing_info['endTime'][0]).strftime('%Y-%m-%d %H:%M:%S'),
          listingType: listing_info['listingType'][0],
          sellerName: selling_status['sellingState'][0],
          sellingStatus: selling_status['sellingState'][0],
          conditionItem: false,
          pictureURLSuperSize: i['pictureURLSuperSize']?i['pictureURLSuperSize'][0]:nil,
          viewItemURL: i['viewItemURL'][0],
          quantityAVL: false,
          quantitySold: false,
          hitCount: false,
          watchCount: listing_info['watchCount'] ? listing_info['watchCount'][0] : 0
        )
        p_insert << product
      end
      s_insert.add i['sellerInfo'][0]['sellerUserName'][0]
    end

    # bulk insert
    p_insert.each do |i|
      single_item = $ebay.get_single_item(i.itemId)
      shipping_cost = $ebay.get_shipping_costs(i.itemId)
      next if !(single_item && shipping_cost)
      item = single_item['Item']
      i.shippingServiceName   = shipping_cost['ShippingCostSummary']?shipping_cost['ShippingCostSummary']['ShippingServiceName']:null
      i.conditionItem         = item['ConditionDisplayName']?item['ConditionDisplayName']:''
      i.quantityAVL           = item['Quantity']?item['Quantity']:false
      i.quantitySold          = item['QuantitySold']?item['QuantitySold']:false
      i.hitCount              = item['HitCount']?item['HitCount']:false
    end
    Product.import p_insert

    # update
    ActiveRecord::Base.transaction do
      con = ActiveRecord::Base.connection
      p_update.each do |u|
        sql = ActiveRecord::Base.send(
          :sanitize_sql_array,
          ['update products
            set countDayAppear=(
                case 
                when countDayAppear<30 then countDayAppear+1
                else 1
                end
            ), isDelete=0, isReproduct=(
                case 
                when countDayAppear<30 then isReproduct
                else 1
                end
            )
            where itemId=:item_id and viewItemURL=:view_item_url',
            item_id: u[:item_id], view_item_url: u[:view_item_url]
          ])
        con.execute sql
      end
    end

    # seller bulk insert
    Seller.import(s_insert.map{|s_n|
      seller = Seller.check_seller(s_n) ? Seller.where(name: s_n).first : Seller.new(name: s_n)
      url = "https://feedback.ebay.com/ws/eBayISAPI.dll?ViewFeedback2&userid=#{s_n}"
      html = Nokogiri::HTML(open(url))
      month_positive = html.xpath('//*[@id="recentFeedbackRatingsTable"]/tr[2]/td[3]/a').text
      seller.countPositive = month_positive.to_i
      seller
    }, on_duplicate_key_update: [:name])

    # distinct
    con = ActiveRecord::Base.connection
    con.execute('DELETE FROM products WHERE id NOT IN (SELECT min_id from (SELECT MIN(id) min_id FROM products GROUP BY itemID, viewItemURL) as tmp)')
    con.execute('DELETE FROM sellers WHERE id NOT IN (SELECT min_id from (SELECT MIN(id) min_id FROM sellers GROUP BY name) as tmp)')
  end
end