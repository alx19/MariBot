class Petitioner
  OPTIONS = %w[
    Предложить\ мероприятие Пройти\ регистрацию
    Изменить\ организацию Изменить\ имя
  ].freeze

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

    return handle_custom_option(@message.text) if OPTIONS.include?(@message.text)

    state_machine
  end

  private

  def state_machine
    case @state
    when nil
      send_message(chat_id: @id, text: replies['start'])
      sleep(1)
      set_state
      state_machine
    when 'options'
      send_keyboard
    when 'get_name'
      set_info('name')
      if registrated?
        handle_request
      else
        send_message(chat_id: @id, text: replies['registration']['organization']['message'])
      end
    when 'get_organization'
      set_info('organization')
      handle_request
    when 'registrated'
      send_message(chat_id: @id, text: replies['registration']['finished']['message'])
      send_keyboard
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
      send_keyboard
      send_message(chat_id: MARI_ID, text: mari_notification, reply_markup: mari_keyboard, parse_mode: 'HTML')
      set_state
    end
  end

  def send_message(params)
    @bot.api.send_message(**params)
  rescue => e
    MyLogger.new.log(e, params[:text])
  end

  def send_keyboard
    options = if registrated?
                OPTIONS
              else
                %w[Пройти\ регистрацию]
              end
    kb = options.map { |o| [Telegram::Bot::Types::KeyboardButton.new(text: o)] }
    markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: kb, one_time_keyboard: true)
    send_message(chat_id: @id, text: 'Что вы хотите сделать?', reply_markup: markup)
  end

  def handle_custom_option(option)
    case option
    when 'Пройти регистрацию'
      if registrated?
        send_message(chat_id: @id, text: replies['registration']['noneed']['message'])
        send_keyboard
      else
        set_state('get_name')
        send_message(chat_id: @id, text: replies['registration']['name']['message'])
      end
    when 'Предложить мероприятие'
      set_state('event_name_request')
      state_machine
    when 'Изменить имя'
      set_state('get_name')
      send_message(chat_id: @id, text: replies['registration']['name']['message'])
    when 'Изменить организацию'
      set_state('get_organization')
      send_message(chat_id: @id, text: replies['registration']['organization']['message'])
    end
  end

  def set_info(type)
    REDIS.set("#{@id}_#{type}", @message.text)
    if registrated?
      set_state('options')
    else
      set_state
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

  def set_state(selected_state = nil)
    selected_state ||= next_state
    REDIS.set("#{@id}_state", selected_state)
    @state = selected_state
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

  def registrated?
    name && organization
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
    when nil then 'options'
    when 'get_name' then 'get_organization'
    when 'get_organization' then 'registrated'
    when 'registrated' then 'event_name_request'
    when 'event_name_request' then 'date_request'
    when 'date_request' then 'place_request'
    when 'place_request' then 'info_request'
    when 'info_request' then 'submitted'
    when 'submitted' then 'options'
    end
  end

  def mari_notification
    event_info = REDIS.hmget(global_id, 'username', 'event_name', 'date', 'place', 'info')
    [
      "Пользователь <a href=\"tg://user?id=#{@id}\">#{name}</a> @#{event_info[0]} прислал запрос на мероприятие.",
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
      [Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Принять', callback_data: "accept #{global_id}")],
      [Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Отказать по времени', callback_data: "untimely #{global_id}")],
      [Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Отказать', callback_data: "reject #{global_id}")]
    ]
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end
end
