# coding: utf-8

require "json"
require "pp"
require "time"
require "dotenv"
require_relative "https"

Dotenv.load

class TwitterSpace
  def get_json(url, header, params = {})
    body = Https.get(url, header, params)
    JSON.parse(body)
  end

  def post_json(url, header, params = {})
    body = Https.post(url, header, params)
    JSON.parse(body)
  end

  def common_header(guest_token)
    {
      "authorization" => ENV["TWITTER_PUBLIC_TOKEN"],
      "x-csrf-token" => "0",
      "x-guest-token" => guest_token.to_s,
      "x-twitter-active-user" => "yes",
      "x-twitter-client-language" => "ja",
    }
  end

  def guest_token
    header = {
       "authorization" => ENV["TWITTER_PUBLIC_TOKEN"],
    }

    res = post_json("https://api.twitter.com/1.1/guest/activate.json", header)
    res["guest_token"].to_s
  end

  def user_by_screen_name(guest_token, screen_name)
    header = common_header(guest_token)
    params = {
      "variables" => {"screen_name" => screen_name, "withSuperFollowsUserFields" => false}.to_json
    }

    get_json("https://twitter.com/i/api/graphql/6GDwe-wtCzeXZ7mPzDz9Rg/UserByScreenNameWithoutResults", header, params)
  end

  def user_tweets(guest_token, user_id)
    header = common_header(guest_token)

    variables = {
      "userId" => user_id,
      "count" => 20,
      "withTweetQuoteCount" => true,
      "includePromotedContent" => true,
      "withReactions" => false,
      "withSuperFollowsTweetFields" => false,
      "withSuperFollowsUserFields" => false,
      "withUserResults" => false,
      "withVoice" => true,
      "withBirdwatchPivots" => false,
    }

    params = {
      "variables" => variables.to_json
    }

    get_json("https://twitter.com/i/api/graphql/ztDvTHlo6dzf1FQ8eQWcHA/UserTweets", header, params)
  end

  def audio_space_by_id(guest_token, space_id)
    header = common_header(guest_token)

    variables = {
      "id" => space_id,
      "isMetatagsQuery" => false,
      "withReactions" => false,
      "withSuperFollowsTweetFields" => false,
      "withSuperFollowsUserFields" => false,
      "withUserResults" => true,
      "withBirdwatchPivots" => false,
      "withScheduledSpaces" => true
    }

    params = {
      "variables" => variables.to_json
    }

    get_json("https://twitter.com/i/api/graphql/s1e2ZkWQYDRvGzCqA66MJQ/AudioSpaceById", header, params)
  end

  def avatar_content(guest_token, user_id)
    header = common_header(guest_token).merge({
      "Cookie" => "auth_token=#{ENV["AUTH_TOKEN"]}"
    })

    params = {
      "user_ids" => user_id,
      "only_spaces" => true,
    }

    get_json("https://twitter.com/i/api/fleets/v1/avatar_content", header, params)
  end

  def live_video_stream(guest_token, media_key)
    header = common_header(guest_token).merge({
      "Cookie" => "auth_token=#{ENV["AUTH_TOKEN"]}"
    })

    params = {
      "client" => "web",
      "use_syndication_guest_id" => "false",
      "cookie_set_host" => "twitter.com",
    }

    get_json("https://twitter.com/i/api/1.1/live_video_stream/status/#{media_key}", header, params)
  end
end

if $0 == __FILE__
  space = TwitterSpace.new
  screen_name = ARGV.first

  token = space.guest_token()
  puts "guest_token: #{token}"

  user = space.user_by_screen_name(token, screen_name)
  # pp user
  user_id = user["data"]["user"]["rest_id"]
  puts "user_id: #{user_id}"

  content = space.avatar_content(token, user_id)
  if content["users"].size > 0
    space_id = content["users"][user_id]["spaces"]["live_content"]["audiospace"]["broadcast_id"]
    puts "space_id: #{space_id}"
  else
    puts "space offline"
    exit(0)
  end

  audio_space = space.audio_space_by_id(token, space_id)
# pp audio_space

  space_metadata = audio_space["data"]["audioSpace"]["metadata"]
  if space_metadata["state"] == "Ended"
    puts "space ended"
    exit(0)
  end

  media_key = space_metadata["media_key"]
  puts "media_key: #{media_key}"

  stream = space.live_video_stream(token, media_key)
  url = stream["source"]["location"]
  puts "url: #{url}"
end
