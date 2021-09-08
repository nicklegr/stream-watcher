# coding: utf-8

require "json"
require "pp"
require "time"
require "dotenv"
require_relative "https"

Dotenv.load

class TwitterSpace
  def get_json(url, header, params = {}, body = "")
    res = Https.get(url, header, params, body)
    JSON.parse(res, symbolize_names: true)
  end

  def post_json(url, header, params = {}, body = "")
    res = Https.post(url, header, params, body)
    JSON.parse(res, symbolize_names: true)
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
    res[:guest_token].to_s
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

  # user_idsは配列で複数指定できる。配信中のidのみが結果の"users"のキーに含まれる
  # 100件以内。それ以上だと400 Bad Requestが返る
  #
  # ユーザーがホスト・共同ホスト・スピーカーの場合のみavatar_contentの結果に含まれる
  # リスナーの場合は含まれない
  # ホストは admin_twitter_user_ids で確認できる。それ以外は区別できない感じ
  #
  # レートリミットは10 req/min程度の印象
  def avatar_content(guest_token, user_ids)
    header = common_header(guest_token).merge({
      "Cookie" => "auth_token=#{ENV["AUTH_TOKEN"]}"
    })

    params = {
      "user_ids" => user_ids.join(","),
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

  def authenticate_periscope(guest_token)
    auth_token = ENV["AUTH_TOKEN"]
    ct0 = ENV["CT0"]

    header = common_header(guest_token).merge({
      "Cookie" => [
        "auth_token=#{auth_token}",
        "ct0=#{ct0}",
      ].join(";"),
      "x-csrf-token" => ct0,
      "x-twitter-auth-type" => "OAuth2Session",
    })

    get_json("https://twitter.com/i/api/1.1/oauth/authenticate_periscope.json", header)
  end

  def periscope_login(twitter_token)
    body = {
      "create_user" => false,
      "direct" => true,
      "jwt" => twitter_token,
      "vendor_id" => "m5-proxsee-login-a2011357b73e",
    }.to_json

    post_json("https://proxsee.pscp.tv/api/v2/loginTwitterToken", {}, {}, body)
  end

  def start_public(guest_token, life_cycle_token)
    header = common_header(guest_token)

    param = {
      "life_cycle_token" => life_cycle_token,
      "auto_play" => true,
    }

    res = Https.get_ret_header("https://proxsee.pscp.tv/api/v2/startPublic", header, param)
    res["Set-Cookie"].match(/^(.+?);/)
    user_id_cookie = $1

    [
      user_id_cookie,
      JSON.parse(res.body)["session"]
    ]
  end

  def stop_public(guest_token, user_id_cookie, session)
    ct0 = ENV["CT0"]

    header = common_header(guest_token).merge({
      "Cookie" => user_id_cookie,
      "x-csrf-token" => ct0,
      "x-twitter-auth-type" => "OAuth2Session",
    })

    param = {
      "session" => session,
    }

    get_json("https://proxsee.pscp.tv/api/v2/stopPublic", header, param)
  end

  def access_chat(cookie, chat_token)
    body = {
      "chat_token" => chat_token,
      "cookie" => cookie,
    }.to_json

    post_json("https://proxsee.pscp.tv/api/v2/accessChat", {}, {}, body)
  end
end

if $0 == __FILE__
  space = TwitterSpace.new
  screen_name = ARGV.first

  token = space.guest_token()
  puts "guest_token: #{token}"

  user = space.user_by_screen_name(token, screen_name)
# pp user
  user_id = user[:data][:user][:rest_id]
  puts "user_id: #{user_id}"

  content = space.avatar_content(token, [ user_id ])
# pp content
  if content[:users].size > 0
    space_id = content[:users][user_id.to_sym][:spaces][:live_content][:audiospace][:broadcast_id]
    puts "space_id: #{space_id}"
  else
    puts "space offline"
    exit(0)
  end

  audio_space = space.audio_space_by_id(token, space_id)
# pp audio_space

  space_metadata = audio_space[:data][:audioSpace][:metadata]
# pp space_metadata
  if space_metadata[:state] == "Ended"
    puts "space ended"
    exit(0)
  end

  media_key = space_metadata[:media_key]
  puts "media_key: #{media_key}"

  stream = space.live_video_stream(token, media_key)
# pp stream
  url = stream[:source][:location]
  puts "stream_url: #{url}"
  puts "chat_token: #{stream[:chatToken]}"

  periscope = space.authenticate_periscope(token)
  puts "periscope_token: #{periscope[:token]}"

  periscope_cookie = space.periscope_login(periscope[:token])
  puts "periscope_cookie: #{periscope_cookie[:cookie]}"

#   ret = space.start_public(token, stream[:lifecycleToken])
# pp ret
# user_id_cookie, session = ret

#   space.stop_public(token, user_id_cookie, session)

  chat = space.access_chat(periscope_cookie[:cookie], stream[:chatToken])
  puts "chat_access_token: #{chat[:access_token]}"
end
