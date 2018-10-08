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
    soalition = Soalitions.new(login: owner).create('hey you', '#', '-')
    friend = random_author
    post = soalition.share(friend, '#')
    assert_equal(1, soalition.posts.count)
    assert_equal(friend, soalition.posts[0].author)
    assert_equal(1, Inbox.new(login: owner).fetch.count)
    assert_equal(0, Inbox.new(login: friend).fetch.count)
    post.approve(owner)
    assert_equal(1, Inbox.new(login: owner).fetch.count)
    assert_equal(0, Inbox.new(login: friend).fetch.count)
  end

  def test_counts_score
    owner = random_author
    soalition = Soalitions.new(login: owner).create('hey you', '#', '-')
    friend = random_author
    post = soalition.share(friend, '#')
    post.approve(owner)
    assert_equal(-1, soalition.score(friend))
  end
end
