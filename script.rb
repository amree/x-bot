require "pry"
require "sinatra"
require "telegram/bot"
require "faraday"
require "httparty"

set :ssl_certificate, "cert.crt"
set :ssl_key, "pkey.pem"
set :port, 9000

CHANNEL_ID = ""
GROUP_ID = ""
CHANNEL_ID = ""
IMGUR_CLIENT_ID = ""

def cmd_search(keyword)
  `xdotool mousemove 828 159 && \
    xdotool click 1 && \
    xdotool mousemove 828 200 && \
    xdotool click 1 && \
    xdotool type #{keyword} && \
    xdotool key Return && \
    xdotool mousemove 1355 183 && \
    xdotool click 1`
end

def cmd_screenshot(filename)
  `maim --quiet --delay=2 --format=png --geometry=628x255+812+625 ./images/#{filename}`
end

def process_and_send_message(message)
  logger.info("MESSAGE: #{message}")

  token = ENV["TOKEN"]
  telegram_url = "https://api.telegram.org/bot#{token}"
  puts telegram_url
  msg = JSON.parse(message, object_class: OpenStruct)
  text = msg&.message&.text

  if text.nil?
    logger.info("SKIP")

    return
  end

  # Start checking
  member = true

  client = Telegram::Bot::Client.new(ENV["TOKEN"], timeout: 60)

  begin
    res1 = client.api.get_chat_member(chat_id: GROUP_ID, user_id: msg.message.from.id)
    res2 = client.api.get_chat_member(chat_id: CHANNEL_ID, user_id: msg.message.from.id)

    if res1["result"]["status"] == "left" && res2["result"]["status"] == "left"
      raise "Kantoi"
    end
  rescue
    member = false

    client.api.send_message(
      chat_id: CHANNEL_ID,
      text: "INVALID MEMBER: #{msg.message.from.first_name} @#{msg.message.from.username}"
    )
  end

  unless member
    client.api.send_message(chat_id: msg.message.chat.id, text: "Hubungi @ultrasaham untuk akses :)")

    return
  end

  # Checking end

  chat_id = msg.message.chat.id

  unless text.match?(/^[A-Za-z0-9-]+$/)
    client = Telegram::Bot::Client.new(ENV["TOKEN"], timeout: 60)
    # Ignore stupid messages
    # client.api.send_message(chat_id: chat_id, text: "Not supported")
  end

  logger.info("SEARCH: #{text}")

  # xrandr --output `xrandr | grep " connected" | cut -f1 -d""` --mode 1440x900
  `change_res`

  current_time = Time.now.strftime("%d-%m-%Y %I:%M:%S %p (%A)")
  filename = "#{Time.now.to_i}-#{text.tr("&", "-").upcase}.png"

  cmd_search(text)
  cmd_screenshot(filename)

  photo = Faraday::UploadIO.new("images/#{filename}", "image/png")

  caption = "#{text.upcase} at #{current_time}"

  logger.info("Sending...")

  logger.info("Sending to user")
  response = HTTParty.post(
    "#{telegram_url}/sendPhoto",
    body: {
      chat_id: chat_id,
      caption: caption,
      photo: photo,
    },
  )

  raise response.to_s unless response["ok"]

  photo_file_id = response.dig("result", "photo", 1, "file_id")

  logger.info("Sending to group")
  response = HTTParty.post(
    "#{telegram_url}/sendPhoto",
    body: {
      chat_id: CHANNEL_ID,
      caption: caption,
      photo: photo_file_id,
    },
  )

  raise response.to_s unless response["ok"]

  logger.info("Sent!")
rescue => error
  logger.info(error)
end

# ENDPOINT

post "/search" do
  process_and_send_message(request.body.read)

  "OK"
end

get "/health" do
  "OK"
end

