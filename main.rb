require 'bundler/setup'
require 'pp'
require 'set'

require 'dotenv'
Dotenv.load File.expand_path('../config/.env', __FILE__)

category = 'Antiques'

require_relative 'include/ebay/ebay'
$ebay = Ebay.new(ENV['EBAY_APP_KEY'])
$ebay.extend(Ebay::FindingService)
$ebay.extend(Ebay::ShoppingService)
puts "total num: #{$ebay.all_items_count_by_cat('20081')}"

require_relative 'worker/crawler'
def update(category_id, min_price, max_price=nil)
  page_number = 1
  loop do
    p_insert = []
    p_update = []
    s_insert = Set.new
    puts "page_number: #{page_number}"

    result = $ebay.find_items_advanced(category_id, 100, page_number, min_price, max_price)
    Crawler.perform_async(result)

    break if page_number == result['findItemsAdvancedResponse'][0]['paginationOutput'][0]['totalPages'][0].to_i
    page_number += 1
  end
end

current_price = 0
loop do
  remaining_count = $ebay.find_items_advanced('20081', 1, 1, current_price)['findItemsAdvancedResponse'][0]['paginationOutput'][0]['totalEntries'][0].to_i
  if remaining_count <= 10000 then
    print "price:to end count:#{remaining_count}"
    update('20081', current_price)
    break
  end
  span = nil
  count = nil
  (1..10).to_a.map{|i| i*10}.reverse.each do |s|
    count = $ebay.find_items_advanced('20081', 1, 1, current_price, current_price+s)['findItemsAdvancedResponse'][0]['paginationOutput'][0]['totalEntries'][0].to_i
    if count <= 10000 then
      span = s
      update('20081', current_price, current_price+s)
      current_price += s
      break
    end
  end
  puts current_price
  puts "price:#{current_price-span}-#{current_price} count:#{count}"
end