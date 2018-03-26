require 'bundler/setup'
require 'pp'
require 'set'

require 'dotenv'
Dotenv.load File.expand_path('../config/.env', __FILE__)

categories = [
  '20081',
  '550',
  '2984',
  '267',
  '12576',
  '625',
  '15032',
  '11450',
  '11116',
  '1',
  '58058',
  '293',
  '14339',
  '237',
  '11232',
  '45100',
  '172008',
  '26395',
  '11700',
  '281',
  '11233',
  '619',
  '1281',
  '870',
  '10542',
  '316',
  '888',
  '64482',
  '260',
  '220',
  '3252',
  '1249',
  '99'
]

require_relative 'include/ebay/ebay'
$ebay = Ebay.new(ENV['EBAY_APP_KEY'])
$ebay.extend(Ebay::FindingService)
$ebay.extend(Ebay::ShoppingService)

require_relative 'worker/crawler'
def update(category_id, min_price, max_price=nil)
  page_number = 1
  loop do
    puts "page_number: #{page_number}"

    result = $ebay.find_items_advanced(category_id, 100, page_number, min_price, max_price)
    Crawler.perform_async(result)

    break if page_number == result['findItemsAdvancedResponse'][0]['paginationOutput'][0]['totalPages'][0].to_i
    page_number += 1
  end
end

categories.each do |cat|
  puts "category id:#{cat}"
  puts "total num: #{$ebay.all_items_count_by_cat(cat)}"

  current_price = 0
  loop do
    remaining_count = $ebay.find_items_advanced(cat, 1, 1, current_price)['findItemsAdvancedResponse'][0]['paginationOutput'][0]['totalEntries'][0].to_i
    if remaining_count <= 10000 then
      puts "price:to end count:#{remaining_count}"
      update(cat, current_price)
      break
    end
    span = nil
    count = nil
    (1..10).to_a.map{|i| i}.reverse.each do |s|
      count = $ebay.find_items_advanced(cat, 1, 1, current_price, current_price+s)['findItemsAdvancedResponse'][0]['paginationOutput'][0]['totalEntries'][0].to_i
      if count <= 10000 then
        span = s
        update(cat, current_price, current_price+s)
        current_price += s
        break
      end
    end
    if !span then
      span = 1
      update(cat, current_price, current_price+span)
      current_price += span
      count = $ebay.find_items_advanced(cat, 1, 1, current_price, current_price+span)['findItemsAdvancedResponse'][0]['paginationOutput'][0]['totalEntries'][0].to_i
    end
    puts "price:#{current_price-span}-#{current_price} count:#{count}"
  end
end

puts 'waiting jobs'
require 'sidekiq/api'
queue = Sidekiq::Queue.new
workers = Sidekiq::Workers.new

require 'active_record'
require 'activerecord-import/base'
while queue.size || workers.size do
  sleep(10)
  con = ActiveRecord::Base.connection
  con.execute('DELETE FROM products WHERE id NOT IN (SELECT min_id from (SELECT MIN(id) min_id FROM products GROUP BY itemID, viewItemURL) as tmp)')
  con.execute('DELETE FROM sellers WHERE id NOT IN (SELECT min_id from (SELECT MIN(id) min_id FROM sellers GROUP BY name) as tmp)')
end