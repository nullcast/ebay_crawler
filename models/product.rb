require_relative 'base'
class Product < ActiveRecord::Base
  def self.check_product(item_id, view_item_url)
    self.exists?(
      itemId: item_id,
      viewItemURL: view_item_url
    )
  end
end