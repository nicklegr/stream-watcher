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

get "/api/v1/twitter_space/:id_type/:name_or_id" do
  content_type "application/json"

  id_type = params[:id_type]

  space = TwitterSpace.new
  token = space.guest_token()

  user_id =
    if id_type == "screen_name"
      screen_name = params[:name_or_id]
      user = space.user_by_screen_name(token, screen_name)
      user["data"]["user"]["rest_id"]
    else
      params[:name_or_id]
    end

  content = space.avatar_content(token, [ user_id ])
  if content["users"].size > 0
    space_id = content["users"][user_id]["spaces"]["live_content"]["audiospace"]["broadcast_id"]
  else
    return {
      "online" => false,
      "user_id" => user_id,
    }.to_json
  end

  audio_space = space.audio_space_by_id(token, space_id)

  space_metadata = audio_space["data"]["audioSpace"]["metadata"]
  if space_metadata["state"] != "Running"
    return {
      "online" => false,
      "user_id" => user_id,
    }.to_json
  end

  media_key = space_metadata["media_key"]

  stream = space.live_video_stream(token, media_key)
  stream_url = stream["source"]["location"]

  {
    "online" => true,
    "user_id" => user_id,
    "screen_name" => space_metadata["creator_results"]["result"]["legacy"]["screen_name"],
    "space_id" => space_id,
    "media_key" => media_key,
    "live_title" => space_metadata["title"],
    "stream_url" => stream_url,
    "space_metadata" => space_metadata,
  }.to_json
end
