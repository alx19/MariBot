class Mari
  def initialize(bot, message)
    @bot = bot
    @message = message
    @replies ||= YAML.load_file('replies.yml')
  end

  def handle_request
    if @message.respond_to? 'data'
      verdict, chat_id, username = @message.data.split
      @bot.api.send_message(chat_id: chat_id, text: @replies['verdict']['user'][verdict])
      @bot.api.send_message(chat_id: chat_id, text: replies['waiting']['message'])
      @bot.api.send_message(chat_id: MARI_ID, text: @replies['verdict']['mari'][verdict] + username)
    else
      @bot.api.send_message(chat_id: MARI_ID, text: 'Да, вы Мари!')
    end
  end
end
