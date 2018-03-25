require_relative 'base'
class Seller < ActiveRecord::Base
  def self.check_seller(name)
    self.exists?(
      name: name
    )
  end
end