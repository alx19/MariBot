class Bot
  def initialize(message, bot)
    return if message.nil? || message.from.nil?

    @bot = bot
    @message = message
    @user_id = message.from.id
  end

  def handle_request
    user.handle_request
  end

  private

  def user
    if message_from_mari?
      Mari.new(@bot, @message)
    else
      Petitioner.new(@user_id, @bot, @message)
    end
  end

  def message_from_mari?
    @user_id == MARI_ID
  end
end
