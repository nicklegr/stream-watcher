FROM ruby:3.0.2

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

WORKDIR /app

# スクリプトに変更があっても、bundle installをキャッシュさせる
COPY Gemfile /app/
COPY Gemfile.lock /app/
RUN bundle install --deployment --without=test --jobs 4

COPY . /app/

# 長期に実行している ENTRYPOINT の実行バイナリに対し、 docker stop で適切にシグナルを送るには、 exec で起動する必要がある
ENTRYPOINT exec bundle exec rackup -o 0.0.0.0 -p $PORT
