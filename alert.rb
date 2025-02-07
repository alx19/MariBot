require 'telegram/bot'

if `pgrep --f "ruby main.rb"`.split("\n").count == 1
  Telegram::Bot::Client.new('spoonbot_token').api.send_message(chat_id: 173948014, text: 'бот Мари упал!')
end
