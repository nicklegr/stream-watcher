# coding: utf-8

Encoding.default_external = Encoding::UTF_8

require File.expand_path(File.dirname(__FILE__)) + '/web'
run Sinatra::Application
