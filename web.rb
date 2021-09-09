# coding: utf-8

require "pp"
require "json"
require "sinatra"
require "sinatra/reloader"
require "sinatra/url_for"
require "open-uri"
require "dotenv"
require_relative "https"
require_relative "twitter_space"

Dotenv.load

get "/" do
  "ok"
end

get "/api/v1/mildom/:user_id" do
  user_id = params[:user_id]

  params = {
    "user_id" => user_id,
    "__cluster" => "aws_japan",
    "__platform" => "web",
    "__la" => "ja",
    "sfr" => "pc",
    "__fc" => "Japan",
    "mark" => "1",
  }

  res = Https.get("https://cloudac-cf-jp.mildom.com/nonolive/gappserv/live/enterstudio", {}, params)

  data = JSON.parse(res)

  if data["code"] != 0
    return [500, "mildom api error: code = #{data["code"]}"]
  end

  body = data["body"]

  # 公開ライブは11
  # オフラインは13
  # TODO: サブスク限定ライブ時の値を確認
  online = body["anchor_live"] != 13

  ret = {
    "online" => online,
    "user_id" => user_id,
    "user_name" => body["loginname"],
    "live_title" => body["anchor_intro"],
    "stream_id" => body["log_id"],
    "raw_response" => data,
  }

  content_type "application/json"
  ret.to_json
end

post "/api/v1/twitter_space/bulk_check" do
  content_type "application/json"

  begin
    begin
      body = JSON.parse(request.body.read, symbolize_names: true)
    rescue JSON::ParserError => e
      return [400, {error: "Invalid request param: #{e.message}"}.to_json]
    end

    unless body in {user_ids: Array => user_ids}
      return [400, {error: "Invalid request param"}.to_json]
    end

    space = TwitterSpace.new
    token = space.guest_token()

    spaces = []
    user_ids.each_slice(100) do |slice|
      content = space.avatar_content(token, slice)
      spaces += content.fetch(:users).values
    end

    # 複数のユーザーが同じスペースにいる場合があるのでuniq
    space_ids = spaces.map do |e|
      e => {spaces: {live_content: {audiospace: {broadcast_id: }}}}
      broadcast_id
    end
    space_ids.uniq!

    results = space_ids.map do |space_id|
      audio_space = space.audio_space_by_id(token, space_id)
      audio_space => {data: {audioSpace: {metadata: space_metadata}}}

      # タイトルがないときはキー自体が存在しないので追加
      space_metadata[:title] ||= ""
      space_metadata => {
        state:,
        media_key:,
        creator_results: {result: {rest_id: user_id, legacy: {screen_name: }}},
        title:,
      }

      if state != "Running"
        nil
      else
        stream = space.live_video_stream(token, media_key)
        stream => {chatToken:, source: {location: stream_url}}

        periscope = space.authenticate_periscope(token)
        periscope_cookie = space.periscope_login(periscope.fetch(:token))
        chat = space.access_chat(periscope_cookie.fetch(:cookie), chatToken)

        {
          "online" => true,
          "user_id" => user_id,
          "screen_name" => screen_name,
          "space_id" => space_id,
          "media_key" => media_key,
          "live_title" => title,
          "stream_url" => stream_url,
          "chat_access_token" => chat.fetch(:access_token),
          "space_metadata" => space_metadata,
        }
      end
    end

    results.compact.to_json
  rescue Net::HTTPExceptions => e
    res = e.response
    [
      res.code.to_i,
      {
        error: "API error",
        code: res.code.to_i,
        body: res.body,
      }.to_json
    ]
  rescue NoMatchingPatternError, KeyError => e
    [500, {error: "JSON parse failed: #{e.message}"}.to_json]
  end
end

get "/api/v1/twitter_space/:id_type/:name_or_id" do
  content_type "application/json"

  begin
    unless params in {id_type: "screen_name" | "user_id" => id_type, name_or_id: }
      return [400, {error: "Invalid request param"}.to_json]
    end

    space = TwitterSpace.new
    token = space.guest_token()

    if id_type == "screen_name"
      screen_name = name_or_id
      user = space.user_by_screen_name(token, screen_name)
      user => {data: {user: {rest_id: user_id}}}
    else
      user_id = name_or_id
    end

    content = space.avatar_content(token, [ user_id ])
    if content.fetch(:users).size > 0
      data = content.dig(:users, user_id.to_sym)
      data => {spaces: {live_content: {audiospace: {broadcast_id: space_id}}}}
    else
      return {
        "online" => false,
        "user_id" => user_id,
      }.to_json
    end

    audio_space = space.audio_space_by_id(token, space_id)
    audio_space => {data: {audioSpace: {metadata: space_metadata}}}

    # タイトルがないときはキー自体が存在しないので追加
    space_metadata[:title] ||= ""
    space_metadata => {
      state:,
      media_key:,
      creator_results: {result: {legacy: {screen_name: }}},
      title:,
    }

    if state != "Running"
      return {
        "online" => false,
        "user_id" => user_id,
      }.to_json
    end

    stream = space.live_video_stream(token, media_key)
    stream => {chatToken:, source: {location: stream_url}}

    periscope = space.authenticate_periscope(token)
    periscope_cookie = space.periscope_login(periscope.fetch(:token))
    chat = space.access_chat(periscope_cookie.fetch(:cookie), chatToken)

    {
      "online" => true,
      "user_id" => user_id,
      "screen_name" => screen_name,
      "space_id" => space_id,
      "media_key" => media_key,
      "live_title" => title,
      "stream_url" => stream_url,
      "chat_access_token" => chat.fetch(:access_token),
      "space_metadata" => space_metadata,
    }.to_json
  rescue Net::HTTPExceptions => e
    res = e.response
    [
      res.code.to_i,
      {
        error: "API error",
        code: res.code.to_i,
        body: res.body,
      }.to_json
    ]
  rescue NoMatchingPatternError, KeyError => e
    [500, {error: "JSON parse failed: #{e.message}"}.to_json]
  end
end
