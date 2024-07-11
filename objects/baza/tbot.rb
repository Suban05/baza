# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'iri'
require 'always'
require 'loog'
require 'telepost'
require 'securerandom'

# Telegram Bot.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Tbot
  # Fake tbot.
  class Fake
    def notify(human, msg)
      # nothing
    end
  end

  def initialize(pgsql, token, loog: Loog::NULL)
    @pgsql = pgsql
    @tp = token.empty? ? Telepost::Fake.new : Telepost.new(token)
    @loog = loog
    @always = Always.new(1).on_error { |e, _| @loog.error(Backtrace.new(e)) }
  end

  def to_s
    @always.to_s
  end

  def start
    @always.start do
      @tp.run do |chat, message|
        @loog.debug("TG incoming message in chat ##{chat.id}: #{message.inspect}")
        entry(chat)
      end
    end
  end

  # Reply to the user in the chat and return user's secret.
  # @return [String] Secret to use in web auth
  def entry(chat)
    chat = chat.id unless chat.is_a?(Integer)
    if @pgsql.exec('SELECT id FROM telechat WHERE id = $1', [chat]).empty?
      @pgsql.exec(
        'INSERT INTO telechat (id, secret) VALUES ($1, $2)',
        [chat, SecureRandom.uuid]
      )
    end
    row = @pgsql.exec(
      [
        'SELECT human.id, human.github, telechat.secret FROM telechat',
        'LEFT JOIN human ON human.id = telechat.human',
        'WHERE telechat.id = $1'
      ],
      [chat]
    )[0]
    if row['id'].nil?
      auth = Iri.new('https://www.zerocracy.com')
        .append('tauth')
        .add(secret: row['secret'])
      @tp.post(
        chat,
        [
          'I don\'t know you yet, please ',
          "[click here](#{auth}) ",
          'in order to authenticate.'
        ].join
      )
      @loog.debug("Invited user to authenticat, in TG chat ##{chat}")
    else
      @tp.post(
        chat,
        "I know that you are `@#{row['github']}`"
      )
      @loog.debug("Greeted user @#{row['github']} in TG chat ##{chat}")
    end
    row['secret']
  end

  def notify(human, msg)
    row = @pgsql.exec('SELECT id FROM telechat WHERE human = $1', [human.id])[0]
    return if row.nil?
    @tp.post(row['chat'].to_i, msg)
  end

  # Authentical the user and return his chat ID in Telegram.
  # @return [Integer] Chat ID in TG
  def auth(human, secret)
    rows = @pgsql.exec('UPDATE telechat SET human = $1 WHERE secret = $2 RETURNING id', [human.id, secret])
    raise Baza::Urror, 'There is no user by this authentication code' if rows.empty?
    rows.first['id'].to_i
  end
end
