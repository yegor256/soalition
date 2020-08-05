# frozen_string_literal: true

# Copyright (c) 2018-2020 Yegor Bugayenko
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
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
require_relative 'test__helper'
require_relative '../objects/tbot'
require_relative '../objects/audits'
require_relative '../objects/soalitions'

class AuditsTest < Minitest::Test
  def test_retrieves_audits
    Audits.new(pgsql: test_pgsql).each { |a| a.deliver(Tbot::Fake.new) }
    tbot = Tbot::Fake.new
    owner = random_author
    soalition = Soalitions.new(login: owner, pgsql: test_pgsql).create('hey you', random_uri, '-')
    friend = random_author
    Soalitions.new(login: friend, pgsql: test_pgsql).join(soalition.id)
    Audits.new(pgsql: test_pgsql).each do |a|
      a.deliver(tbot)
    end
    Audits.new(pgsql: test_pgsql).each { raise 'There should be no audits left' }
    assert_equal(3, tbot.sent.count)
    assert(tbot.sent[0].include?("#{friend}: You have been kicked out"), tbot.sent.to_s)
    assert(tbot.sent[1].include?("#{owner}: The user `@#{friend}` has been kicked out"), tbot.sent.to_s)
    assert(tbot.sent[2].include?("@#{owner}:  +0"), tbot.sent.to_s)
  end
end
