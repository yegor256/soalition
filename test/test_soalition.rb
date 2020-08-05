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
require_relative '../objects/soalitions'
require_relative '../objects/inbox'

class SoalitionTest < Minitest::Test
  def test_shares_post
    owner = random_author
    uri = random_uri
    soalitions = Soalitions.new(login: owner, pgsql: test_pgsql)
    soalition = soalitions.create('hey you', uri, '-')
    friend = random_author
    Soalitions.new(login: friend, pgsql: test_pgsql).join(soalition.id)
    post = soalition.share(friend, uri)
    assert_equal(1, soalition.posts.count)
    assert_equal(friend, soalition.posts[0].author)
    assert_equal(1, Inbox.new(login: owner, pgsql: test_pgsql).fetch.count)
    assert_equal(0, Inbox.new(login: friend, pgsql: test_pgsql).fetch.count)
    post.approve(owner)
    assert_equal(1, Inbox.new(login: owner, pgsql: test_pgsql).fetch.count)
    assert_equal(0, Inbox.new(login: friend, pgsql: test_pgsql).fetch.count)
  end

  def test_lists_members
    owner = random_author
    soalitions = Soalitions.new(login: owner, pgsql: test_pgsql)
    soalition = soalitions.create('hey you', random_uri, '-')
    assert(soalition.admin?(owner))
    assert_equal(1, soalition.members.count)
    Soalitions.new(login: random_author, pgsql: test_pgsql).join(soalition.id)
    assert_equal(2, soalition.members.count)
    assert(soalition.members[0][:login])
    assert(!soalition.members[0][:telegram].nil?)
  end

  def test_counts_score
    owner = random_author
    uri = random_uri
    soalition = Soalitions.new(login: owner, pgsql: test_pgsql).create('hey you', uri, '-')
    friend = random_author
    Soalitions.new(login: friend, pgsql: test_pgsql).join(soalition.id)
    post = soalition.share(friend, uri)
    post.approve(owner)
    assert_equal(2, soalition.score(friend))
  end

  def test_joins_and_quits
    owner = random_author
    soalitions = Soalitions.new(login: owner, pgsql: test_pgsql)
    soalition = soalitions.create('hey you', random_uri, '-')
    friend = random_author
    Soalitions.new(login: friend, pgsql: test_pgsql).join(soalition.id)
    assert_equal(2, soalition.members.count)
    soalition.quit(friend)
    assert_equal(1, soalition.members.count)
  end
end
