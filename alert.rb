require 'telegram/bot'

if `pgrep --f "ruby main.rb"`.split("\n").count == 1
  Telegram::Bot::Client.new('6024269718:AAHcTb7c-2XmHk9jiwoUDaiK7VZsCPzO_fA').api.send_message(chat_id: 173948014, text: 'бот Мари упал!')
end
