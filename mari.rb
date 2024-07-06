class Mari
  def initialize(admin_id, bot, message)
    @admin_id = admin_id
    @bot = bot
    @message = message
    @replies ||= YAML.load_file('replies.yml')
  end

  def handle_request
    case @message
    when Telegram::Bot::Types::CallbackQuery
      @verdict, @global_id = @message.data.split
      event_data
      send_message(chat_id: @chat_id, text: prepare_verdict('user'))
      send_message(chat_id: @chat_id, text: @replies['waiting']['message'])
      update_messages
    when Telegram::Bot::Types::Message
      send_message(chat_id: @admin_id, text: 'Да, вы Мари! Ну или Алиса.')
    end
  end

  private

  def update_messages
    messages = REDIS.hmget("messages_#{@global_id}", 'text', MARI_ID, ALICE_ID)
    new_text = [messages[0], who_edit, verdict_to_ru].join("\n")
    edit_message(text: new_text, chat_id: MARI_ID, message_id: messages[1].to_i, parse_mode: 'HTML')
    edit_message(text: new_text, chat_id: ALICE_ID, message_id: messages[2].to_i, parse_mode: 'HTML')
  end

  def send_message(params)
    begin
      @bot.api.send_message(**params)
    rescue
    end
  end

  def edit_message(params)
    @bot.api.edit_message_text(**params)
    begin
      @bot.api.edit_message_text(**params)
    rescue
    end
  end

  def who
    case @admin_id
    when MARI_ID then 'Мари'
    when ALICE_ID then 'Алиса'
    end
  end

  def who_edit
    "Ответ был дан пользователем #{who} #{Time.now}"
  end

  def verdict_to_ru
    case @verdict
    when 'accept' then 'Вердикт: ✅'
    when 'reject' then 'Вердикт: ❌'
    when 'untimely' then 'Вердикт: ⌛️'
    end
  end

  def prepare_verdict(person)
    reply = @replies['verdict'][person][@verdict].sub('event_name', @event_name)
    person == 'mari' ? reply + @username : reply
  end

  def event_data
    @chat_id, @username, @event_name = REDIS.hmget(@global_id, 'chat_id', 'username', 'event_name')
    @username = if @username == ''
                  "<a href=\"tg://user?id=#{@chat_id}\">#{@chat_id}</a>"
                else
                  "@#{@username}"
                end
  end
end
