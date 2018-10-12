# frozen_string_literal: true

# Copyright (c) 2018 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'yaml'
require 'telebot'
require_relative 'pgsql'

# Telegram Bot.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class Tbot
  # Fake one
  class Fake
    attr_reader :sent
    def initialize
      @sent = []
    end

    def notify(author, msg)
      @sent << "#{author}: #{msg}"
    end
  end

  def initialize(token: '', pgsql: Pgsql::TEST)
    @token = token
    @pgsql = pgsql
    @client = Telebot::Client.new(token) unless token.empty?
  end

  def identified?(author)
    !@pgsql.exec('SELECT * FROM tchat WHERE author = $1', [author]).empty?
  end

  def identify(author, number)
    @pgsql.exec(
      'INSERT INTO tchat (author, number) VALUES ($1, $2) ON CONFLICT (author) DO UPDATE SET number = $2',
      [author, number]
    )
  end

  def start
    return if @token.empty?
    Telebot::Bot.new(@token).run do |client, message|
      number = message.chat.id
      author = @pgsql.exec(
        'SELECT author FROM tchat WHERE number = $1',
        [number]
      )
      if author.empty?
        post(
          number,
          [
            'Hey, who are you? Please, click',
            "[this link](https://www.soalition.com/tbot?chat=#{number})",
            "so that I can identify you (don't forget to login via Twitter first)."
          ].join(' '),
          c: client
        )
      else
        post(
          number,
          [
            "I know you, you are `@#{author[0]['author']}`!",
            "I can't really talk to you, I'm not a full-featured chat bot.",
            'I will just update you here about the most important events,',
            'which may happen in your [Soalition](https://www.soalition.com) account.'
          ].join(' '),
          c: client
        )
      end
    end
  end

  def notify(author, msg)
    chat = @pgsql.exec(
      'SELECT number FROM tchat WHERE author = $1',
      [author]
    )
    return if chat.empty?
    post(chat[0]['number'].to_i, msg)
  end

  private

  def post(chat, msg, c: @client)
    return if @token.empty?
    c.send_message(
      chat_id: chat,
      parse_mode: 'Markdown',
      disable_web_page_preview: true,
      text: msg
    )
  end
end
