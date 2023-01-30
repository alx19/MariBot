class MyLogger
  def log(message)
    File.open('log.txt', 'a') { |f| f.write "#{Time.now}: #{message}" }
  end
end
