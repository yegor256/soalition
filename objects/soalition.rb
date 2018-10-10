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
require_relative 'post'

# Soalition.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class Soalition
  attr_reader :id

  def initialize(id:, pgsql: Pgsql::TEST, hash: {})
    raise "Soalition Id must be a number: #{id} (#{id.class.name})" unless id.is_a?(Integer)
    raise "Soalition Id must be positive: #{id}" unless id.positive?
    @id = id
    @pgsql = pgsql
    @hash = hash
  end

  def name
    @hash['name'] || @pgsql.exec('SELECT name FROM soalition WHERE id=$1', [@id])[0]['name']
  end

  def description
    @hash['description'] || @pgsql.exec('SELECT description FROM soalition WHERE id=$1', [@id])[0]['description']
  end

  def icon
    @hash['icon'] || @pgsql.exec('SELECT icon FROM soalition WHERE id=$1', [@id])[0]['icon']
  end

  def size
    @pgsql.exec('SELECT COUNT(*) FROM follow WHERE soalition = $1', [@id])[0]['count'].to_i
  end

  def score(author)
    @pgsql.exec(score_query, [@id, author])[0]['score'].to_i
  end

  def share(author, uri)
    raise "Invalid URL \"#{uri}\"" unless URI::DEFAULT_PARSER.make_regexp.match?(uri)
    s = score(author)
    raise "Your score #{s} is too low, you can't share" if s.negative?
    id = @pgsql.exec(
      'INSERT INTO post (author, soalition, uri) VALUES ($1, $2, $3) RETURNING id',
      [author, @id, uri]
    )[0]['id'].to_i
    Post.new(id: id, pgsql: @pgsql)
  end

  def posts
    @pgsql.exec('SELECT * FROM post WHERE soalition = $1 LIMIT 50', [@id]).map do |r|
      Post.new(id: r['id'].to_i, pgsql: @pgsql, hash: r)
    end
  end

  def quit(friend)
    @pgsql.exec('DELETE FROM follow WHERE soalition = $1 AND author = $2', [@id, friend])
  end

  def members(admins_only: false)
    q = [
      "SELECT follow.author, tchat.number, (#{score_query('follow.author')}) AS score FROM follow",
      'LEFT JOIN tchat ON tchat.author = follow.author',
      'WHERE soalition = $1',
      admins_only ? ' AND admin = true' : ''
    ].join(' ')
    @pgsql.exec(q, [@id]).map do |r|
      { login: r['author'], telegram: !r['tchat'].nil?, score: r['score'].to_i }
    end
  end

  private

  def score_query(author = '$2')
    days = 90
    posts = [
      'SELECT COUNT(*) FROM post',
      'JOIN approve ON post.id = approve.post',
      "WHERE soalition = $1 AND post.created > NOW() - INTERVAL '#{days} DAYS'",
      "AND post.author = #{author}"
    ].join(' ')
    reposts = [
      'SELECT COUNT(*) FROM repost',
      'JOIN post ON repost.post = post.id',
      'JOIN soalition ON post.soalition = soalition.id',
      "WHERE soalition = $1 AND repost.created > NOW() - INTERVAL '#{days} DAYS'",
      "AND repost.author = #{author} AND repost.approved = true"
    ].join(' ')
    norma = days / 30
    size = 'SELECT COUNT(*) FROM follow WHERE soalition = $1'
    "SELECT (#{reposts}) + (#{norma} - ABS((#{posts}) - #{norma})) * (#{size}) AS score"
  end
end
