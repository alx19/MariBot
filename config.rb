require 'redis'
require_relative 'petitioner'
require_relative 'mari'
require 'yaml'

REDIS = Redis.new
TOKEN = 'sample'.freeze
MARI_ID = 1
