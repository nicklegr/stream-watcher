# coding: utf-8

require "pp"
require "json"
require "sinatra"
require "sinatra/reloader"
require "sinatra/url_for"
require "open-uri"
require "dotenv"
require_relative "https"

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
