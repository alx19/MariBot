class Mari
  def initialize(bot, message)
    @bot = bot
    @message = message
    @replies ||= YAML.load_file('replies.yml')
  end

  def handle_request
    if @message.respond_to? 'data'
      @verdict, @global_id = @message.data.split
      event_data
      @bot.api.send_message(chat_id: @chat_id, text: prepare_verdict('user'))
      @bot.api.send_message(chat_id: @chat_id, text: @replies['waiting']['message'])
      @bot.api.send_message(chat_id: MARI_ID, text: prepare_verdict('mari'))
    else
      @bot.api.send_message(chat_id: MARI_ID, text: 'Да, вы Мари!')
    end
  end

  def prepare_verdict(person)
    reply = @replies['verdict'][person][@verdict].sub('event_name', @event_name)
    person == 'mari' ? reply + @username : reply
  end

  def event_data
    @chat_id, @username, @event_name = REDIS.hmget(@global_id, 'chat_id', 'username', 'event_name')
  end
end
