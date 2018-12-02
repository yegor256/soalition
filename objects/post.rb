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
require_relative 'reposts'
require_relative 'soalition'
require_relative 'user_error'

# Post.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class Post
  attr_reader :id

  def initialize(id:, pgsql: Pgsql::TEST, hash: {})
    raise "Post Id must be a number: #{id} (#{id.class.name})" unless id.is_a?(Integer)
    raise "Post Id must be positive: #{id}" unless id.positive?
    @id = id
    @pgsql = pgsql
    @hash = hash
  end

  def author
    @hash['author'] || @pgsql.exec('SELECT author FROM post WHERE id = $1', [@id])[0]['author']
  end

  def uri
    @hash['uri'] || @pgsql.exec('SELECT uri FROM post WHERE id = $1', [@id])[0]['uri']
  end

  def approve(author)
    raise UserError, "@#{author} can't approve post ##{@id}" unless allowed(author)
    @pgsql.exec(
      'INSERT INTO approve (post, author) VALUES ($1, $2) RETURNING id',
      [@id, author]
    )
  end

  def reject(author)
    raise UserError, "@#{author} can't reject post ##{@id}" unless allowed(author)
    @pgsql.exec('DELETE FROM post WHERE id = $1', [@id])
  end

  def approved?
    !@pgsql.exec('SELECT * FROM approve WHERE post = $1 LIMIT 1', [@id]).empty?
  end

  def reposts
    Reposts.new(post: self, pgsql: @pgsql)
  end

  def soalition
    id = @pgsql.exec('SELECT soalition FROM post WHERE id = $1 LIMIT 1', [@id])[0]['soalition'].to_i
    Soalition.new(id: id, pgsql: @pgsql)
  end

  private

  def allowed(author)
    !@pgsql.exec(
      [
        'SELECT * FROM follow',
        'JOIN soalition ON follow.soalition = soalition.id',
        'JOIN post ON post.soalition = soalition.id',
        'WHERE follow.author = $1 AND post.id = $2'
      ].join(' '),
      [author, @id]
    ).empty?
  end
end
