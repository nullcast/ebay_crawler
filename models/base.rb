require 'bundler/setup'
require 'active_record'
require 'activerecord-import/base'
require 'yaml'
require 'dotenv'

Dotenv.load File.expand_path('../../config/.env', __FILE__)
config = YAML.load_file(File.expand_path('../../config/database.yml', __FILE__))
# DB接続設定
ActiveRecord::Import.require_adapter('mysql2')
ActiveRecord::Base.establish_connection(config['db'][ENV['ENV'].downcase])
