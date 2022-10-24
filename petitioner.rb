class Petitioner
  def initialize(id, bot, message)
    @id = id
    @bot = bot
    @message = message
    @state = state
  end

  def handle_request
    case @state
    when nil
      @bot.api.send_message(chat_id: @id, text: replies['start'])
      sleep(2)
      @bot.api.send_message(chat_id: @id, text: replies['registration']['name']['message'])
      set_state
    when 'get_name'
      set_info('name')
    when 'get_organization'
      set_info('organization')
    when 'registrated'
      @bot.api.send_message(chat_id: @id, text: replies['registration']['finished']['message'])
      set_state
      handle_request
    when 'date_request'
      @bot.api.send_message(chat_id: @id, text: replies['request']['date']['message'])
      set_state
      set_event
    when 'place_request'
      if @message.text
        set_by_type('date', @message.text)
        @bot.api.send_message(chat_id: @id, text: replies['request']['place']['message'])
        set_state
      else
        @bot.api.send_message(chat_id: @id, text: replies['request']['date']['error'])
      end
    when 'info_request'
      if @message.text
        set_by_type('place', @message.text)
        @bot.api.send_message(chat_id: @id, text: replies['request']['info']['message'])
        set_state
      else
        @bot.api.send_message(chat_id: @id, text: replies['request']['place']['error'])
      end
    when 'submitted'
      if @message.text
        set_by_type('info', @message.text)
        @bot.api.send_message(chat_id: @id, text: replies['request']['submitted']['message'])
        set_state
        handle_request
      else
        @bot.api.send_message(chat_id: @id, text: replies['request']['info']['error'])
      end
    when 'waiting'
      @bot.api.send_message(chat_id: MARI_ID, text: mari_notification, reply_markup: mari_keyboard)
      @bot.api.send_message(chat_id: @id, text: replies['waiting']['message'])
      set_state
    end
  end

  private

  def set_info(type)
    if @message.text
      set_name(@message.text)
      set_state
      @bot.api.send_message(chat_id: @id, text: replies['registration'][type]['message'])
    else
      @bot.api.send_message(chat_id: @id, text: replies['registration'][type]['error'])
    end
  end

  def replies
    @replies ||= YAML.load_file('replies.yml')
  end

  def new?
    @state.nil?
  end

  def state
    REDIS.get("#{@id}_state")
  end

  def set_state
    REDIS.set("#{@id}_state", next_state)
    @state = next_state
  end

  def set_name(name)
    REDIS.set("#{@id}_name", name)
  end

  def set_by_type(type, value)
    REDIS.hmset("#{@id}_#{event_id}", type, value)
  end

  def set_event
    event_id = REDIS.incr('event_id')
    REDIS.set("#{@id}_current_event", event_id)
    REDIS.hmset("#{@id}_#{event_id}", 'username', username)
  end

  def username
    @message.from.username
  end

  def event_id
    REDIS.get("#{@id}_current_event")
  end

  # this state machine is a shame
  def next_state
    case @state
    when nil then 'get_name'
    when 'get_name' then 'get_organization'
    when 'get_organization' then 'registrated'
    when 'registrated' then 'date_request'
    when 'date_request' then 'place_request'
    when 'place_request' then 'info_request'
    when 'info_request' then 'submitted'
    when 'submitted' then 'waiting'
    when 'waiting' then 'date_request'
    end
  end

  def mari_notification
    event_info = REDIS.hmget("#{@id}_#{event_id}", 'username', 'date', 'place', 'info')
    [
      "Пользователь @#{event_info[0]} прислал запрос на мероприятие.",
      "Дата и время: #{event_info[1]}.",
      "Место: #{event_info[2]}",
      "Описание: #{event_info[3]}",
      "ID заявки: #{@id}_#{event_id}"
    ].join("\n")
  end

  def mari_keyboard
    kb = [
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Принять', callback_data: "accept #{callback_data}"),
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Отказать по времени', callback_data: "untimely #{callback_data}"),
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Отказать', callback_data: "reject #{callback_data}")
    ]
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end

  def callback_data
    "#{@id} #{username}"
  end
end
