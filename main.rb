require 'telegram/bot'
require 'redis'
require 'yaml'

require_relative 'petitioner'
require_relative 'mari'
require_relative 'config'
require_relative 'bot'

Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |message|
    Bot.new(message, bot).handle_request
  end
end
