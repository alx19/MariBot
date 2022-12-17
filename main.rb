require 'telegram/bot'
require 'redis'
require 'yaml'

require_relative 'petitioner'
require_relative 'mari'
require_relative 'config'
require_relative 'bot'
require_relative 'logger'

Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |message|
    next if message.nil? || message.from.nil?

    Bot.new(message, bot).handle_request
  end
rescue e
  Logger.new.log(e.message)
  bot.api.send_message(chat_id: MARI_ID, text: 'Бот сломался!')
end
