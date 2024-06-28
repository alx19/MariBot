class Bot
  def initialize(message, bot)
    @bot = bot
    @message = message
    @user_id = message.from.id
  end

  def handle_request
    user.handle_request
  end

  private

  def user
    return if @message.is_a? Telegram::Bot::Types::ChatMemberUpdated

    if message_from_admin?
      Mari.new(@user_id, @bot, @message)
    else
      Petitioner.new(@user_id, @bot, @message)
    end
  end

  def message_from_admin?
    ADMINS.include?(@user_id)
  end
end
