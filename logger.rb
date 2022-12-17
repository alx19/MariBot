class Logger
  def log(message)
    File.open('log.txt', 'w') { |f| f.write "#{Time.now}: #{message}" }
  end
end
