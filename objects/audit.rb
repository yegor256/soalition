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
require_relative 'inbox'

# Audit.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class Audit
  def initialize(id:, pgsql: Pgsql::TEST)
    @id = id
    @pgsql = pgsql
  end

  def soalition
    Soalition.new(id: @id, pgsql: @pgsql)
  end

  def table
    members = soalition.members
    width = members.map { |m| m[:login].length }.max
    members.map do |m|
      [
        format("%-#{width + 2}s", "@#{m[:login]}:"),
        format('%+3d', m[:score]),
        format('%3d', Inbox.new(login: m[:login], pgsql: @pgsql).fetch.count)
      ].join(' ')
    end.join("\n")
  end

  def deliver(tbot)
    members = soalition.members
    loser = members.last
    if loser.nil? || loser[:score].positive? || soalition.admin?(loser[:login])
      loser = nil
    else
      soalition.quit(loser[:login])
      tbot.notify(
        loser[:login],
        [
          'You have been kicked out of the soaltion',
          "[#{soalition.name}](https://www.soalition.com/soalition?id=#{soalition.id})",
          "because your score #{format('%+d', loser[:score])} is the lowest in the group and it's not positive;",
          "you can re-join, just [click here](https://www.soalition.com/join?id=#{soalition.id})."
        ].join(' ')
      )
      soalition.members(admins_only: true).each do |user|
        tbot.notify(
          user[:login],
          [
            "The user `@#{loser[:login]}` has been kicked out from the",
            "[#{soalition.name}](https://www.soalition.com/soalition?id=#{soalition.id}) soalition,",
            "because their score #{format('%+d', loser[:score])} was the lowest",
            "(among #{members.count} other members)."
          ].join(' ')
        )
      end
    end
    soalition.members(admins_only: true).each do |user|
      tbot.notify(
        user[:login],
        [
          "This is what's going on in the",
          "[#{soalition.name}](https://www.soalition.com/soalition?id=#{soalition.id}) soalition,",
          "which you are a proud member of (Twitter handle, score, inbox size):\n\n```\n",
          table,
          "\n```\n\n",
          loser.nil? ? '' : "The least effective user `@#{loser[:login]}` has been kicked out just now.",
          'You can earn more reputation points by re-posting others posts.',
          'Also you can write your own content. Go check [your inbox](https://www.soalition.com/).',
          'You can invite more members by sharing',
          "[this link](https://www.soalition.com/join?id=#{soalition.id}) with them."
        ].join(' ')
      )
    end
    @pgsql.exec('INSERT INTO audit (soalition) VALUES ($1)', [@id])
  end
end
