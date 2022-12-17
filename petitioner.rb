class Petitioner
  def initialize(id, bot, message)
    @id = id
    @bot = bot
    @message = message
    @state = state
  end

  def handle_request
    unless @message.text
      send_message(chat_id: @id, text: replies['error']['message'])
      return
    end

    case @state
    when nil
      send_message(chat_id: @id, text: replies['start'])
      sleep(2)
      set_state
      send_message(chat_id: @id, text: replies['registration']['name']['message'])
    when 'get_name'
      set_info('name')
      send_message(chat_id: @id, text: replies['registration']['organization']['message'])
    when 'get_organization'
      set_info('organization')
      handle_request
    when 'registrated'
      send_message(chat_id: @id, text: replies['registration']['finished']['message'])
      set_state
      handle_request
    when 'event_name_request'
      send_message(chat_id: @id, text: replies['request']['event_name']['message'])
      set_state
      set_event
    when 'date_request'
      set_by_type('event_name', @message.text)
      send_message(chat_id: @id, text: replies['request']['date']['message'])
      set_state
    when 'place_request'
      set_by_type('date', @message.text)
      send_message(chat_id: @id, text: replies['request']['place']['message'])
      set_state
    when 'info_request'
      set_by_type('place', @message.text)
      send_message(chat_id: @id, text: replies['request']['info']['message'])
      set_state
    when 'submitted'
      set_by_type('info', @message.text)
      send_message(chat_id: @id, text: replies['request']['submitted']['message'])
      set_state
      handle_request
    when 'waiting'
      send_message(chat_id: MARI_ID, text: mari_notification, reply_markup: mari_keyboard)
      send_message(chat_id: @id, text: replies['waiting']['message'])
      set_state
    end
  end

  private

  def send_message(params)
    @bot.api.send_message(**params)
  rescue => e
    MyLogger.new.log(e)
  end

  def set_info(type)
    REDIS.set("#{@id}_#{type}", @message.text)
    set_state
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

  def set_by_type(type, value)
    REDIS.hmset("#{@id}_#{event_id}", type, value)
  end

  def set_event
    event_id = REDIS.incr('event_id')
    REDIS.set("#{@id}_current_event", event_id)
    REDIS.hmset("#{@id}_#{event_id}", 'username', username, 'chat_id', @id)
  end

  def username
    @message.from.username
  end

  def name
    REDIS.get("#{@id}_name")
  end

  def organization
    REDIS.get("#{@id}_organization")
  end

  def event_id
    REDIS.get("#{@id}_current_event")
  end

  def global_id
    "#{@id}_#{event_id}"
  end

  # this state machine is a shame
  def next_state
    case @state
    when nil then 'get_name'
    when 'get_name' then 'get_organization'
    when 'get_organization' then 'registrated'
    when 'registrated' then 'event_name_request'
    when 'event_name_request' then 'date_request'
    when 'date_request' then 'place_request'
    when 'place_request' then 'info_request'
    when 'info_request' then 'submitted'
    when 'submitted' then 'waiting'
    when 'waiting' then 'event_name_request'
    end
  end

  def mari_notification
    event_info = REDIS.hmget(global_id, 'username', 'event_name', 'date', 'place', 'info')
    [
      "Пользователь @#{event_info[0]} прислал запрос на мероприятие.",
      "Пользователь представился как: #{name}",
      "Пользователь указал следующую организацию: #{organization}",
      "Пользователь указал следующее название мероприятия: #{event_info[1]}",
      "Дата и время: #{event_info[2]}",
      "Место: #{event_info[3]}",
      "Описание: #{event_info[4]}",
      "ID заявки: #{global_id}"
    ].join("\n")
  end

  def mari_keyboard
    kb = [
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Принять', callback_data: "accept #{global_id}"),
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Отказать по времени', callback_data: "untimely #{global_id}"),
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Отказать', callback_data: "reject #{global_id}")
    ]
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end
end
