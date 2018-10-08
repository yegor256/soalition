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

require_relative 'pgsql'

# Inbox.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class Inbox
  def initialize(login:, pgsql: Pgsql::TEST)
    @login = login
    @pgsql = pgsql
  end

  def fetch
    [
      @pgsql.exec(
        [
          'SELECT post.id, post.author, post.uri, soalition.name, soalition.id as soalition_id FROM post',
          'LEFT JOIN approve ON approve.post = post.id',
          'JOIN soalition ON post.soalition = soalition.id',
          'JOIN follow ON follow.soalition = soalition.id',
          'WHERE follow.author = $1 AND follow.admin = true and approve.id IS NULL'
        ].join(' '),
        [@login]
      ).map do |r|
        [
          "New post shared by [@#{r['author']}](https://twitter.com/#{r['author']})",
          "in [#{r['name']}](/soalition?id=r['soalition_id'])",
          "requires your approval: [#{r['uri']}](#{r['uri']});",
          "please, [approve](/do-approve?id=#{r['id']}) or [reject](/do-reject?id=#{r['id']})."
        ].join(' ')
      end,
      @pgsql.exec(
        [
          'SELECT post.uri, post.author FROM post',
          'JOIN approve ON approve.post = post.id',
          'JOIN soalition ON post.soalition = soalition.id',
          'JOIN follow ON follow.soalition = soalition.id',
          'LEFT JOIN repost ON repost.post = post.id AND repost.author = $1',
          'WHERE follow.author = $1 AND repost.id IS NULL'
        ].join(' '),
        [@login]
      ).map do |r|
        [
          "A new post has been just shared by [@#{r['author']}](https://twitter.com/#{r['author']}),",
          "they ask you to re-post, comment, or like it: [#{r['uri']}](#{r['uri']});",
          "please, [click here](/repost?id=#{r['id']}) when done."
        ].join(' ')
      end
    ].flatten
  end

  def respond
    # ...
  end
end
