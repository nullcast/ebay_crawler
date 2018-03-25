require 'open-uri'
require 'json'
require 'addressable/uri'
require_relative 'service/finding'
require_relative 'service/shipping'

class Ebay
  def initialize(appname)
    @appname = appname
  end

  def url_build(host, path, params)
    uri = Addressable::URI.new
    uri.query_values = params
    URI::HTTP.build({
      :host => host,
      :path => path,
      :query => uri.query
    })
  end

  def call(url)
    begin
      json = open(url) do |f|
        f.read
      end
      result = JSON.load(json)
    rescue => error
      pp error
      p url
      p '通信エラーが発生しました。もう一度コールします。'
      self.call(url)
    end
  end
end