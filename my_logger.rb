class MyLogger
  def log(error, message_text = '')
    File.open('log.txt', 'a') { |f| f.write "#{Time.now}: #{error}, message_text: #{message_text}\n" }
  end
end
