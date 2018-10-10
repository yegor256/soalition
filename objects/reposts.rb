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

require 'uri'
require_relative 'pgsql'

# Reposts.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class Reposts
  def initialize(post:, pgsql: Pgsql::TEST)
    @post = post
    @pgsql = pgsql
  end

  def submit(friend, uri)
    raise "Invalid URL \"#{uri}\"" unless URI::DEFAULT_PARSER.make_regexp.match?(uri)
    raise "You can't repost your own post ##{@id}" if @post.author == friend
    @pgsql.exec(
      'INSERT INTO repost (author, post, uri) VALUES ($1, $2, $3) RETURNING id',
      [friend, @post.id, uri]
    )[0]['id']
  end

  def fetch
    @pgsql.exec('SELECT * FROM repost WHERE post = $1 ORDER BY created DESC', [@post.id])
  end

  def approve(id, friend)
    raise "You are not the author of the post ##{@post.id}" unless @post.author == friend
    author = @pgsql.exec('SELECT author FROM repost WHERE id = $1', [id])[0]['author']
    @pgsql.exec('UPDATE repost SET approved = true WHERE id = $1', [id])
    author
  end

  def reject(id, friend)
    raise "You are not the author of the post ##{@post.id}" unless @post.author == friend
    author = @pgsql.exec('SELECT author FROM repost WHERE id = $1', [id])[0]['author']
    @pgsql.exec('DELETE FROM repost WHERE id = $1', [id])
    author
  end
end
