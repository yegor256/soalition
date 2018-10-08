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
require_relative 'soalition'

# Soalitions.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class Soalitions
  def initialize(login:, pgsql: Pgsql::TEST)
    @login = login
    @pgsql = pgsql
  end

  def create(name, icon, description)
    raise "The name \"#{name}\" is too short (less than 4)" if name.length < 4
    raise "The name \"#{name}\" is too long (over 32)" if name.length > 32
    raise 'The description is too long (over 200)' if description.length > 200
    @pgsql.connect do |c|
      c.transaction do |con|
        soalition = con.exec_params(
          'INSERT INTO soalition (name, icon, description) VALUES ($1, $2, $3) RETURNING id',
          [name, icon, description]
        )[0]['id'].to_i
        con.exec_params(
          'INSERT INTO follow (author, soalition, admin) VALUES ($1, $2, true) RETURNING id',
          [@login, soalition]
        )[0]['id'].to_i
        Soalition.new(id: soalition, pgsql: @pgsql)
      end
    end
  end

  def join(soalition)
    id = @pgsql.exec(
      'INSERT INTO follow (author, soalition) VALUES ($1, $2) RETURNING id',
      [@login, soalition]
    )
    Soalition.new(id: id, pgsql: @pgsql)
  end

  def mine
    @pgsql.exec(
      [
        'SELECT * FROM soalition',
        'JOIN follow ON follow.soalition = soalition.id',
        'WHERE follow.author = $1'
      ].join(' '),
      [@login]
    ).map { |r| Soalition.new(id: r['id'], pgsql: @pgsql, hash: r) }
  end

  def one(id)
    found = @pgsql.exec(
      [
        'SELECT * FROM soalition',
        'JOIN follow ON follow.soalition = soalition.id',
        'WHERE soalition.id = $1 AND follow.author = $2',
        'LIMIT 1'
      ].join(' '),
      [id, @login]
    )
    raise "Soalition ##{id} not found for @#{@login}" if found.empty?
    Soalition.new(id: found[0]['id'], pgsql: @pgsql, hash: found[0])
  end
end
