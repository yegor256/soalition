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

class PostTest < Minitest::Test
  def test_shares_post
    owner = random_author
    soalition = Soalitions.new(login: owner).create('hey you', '#', '-')
    post = soalition.share(random_author, '#')
    assert_equal('#', post.uri)
    assert(!post.approved?)
    assert_raises do
      post.approve('stranger')
    end
    post.approve(owner)
    assert(post.approved?)
  end

  def test_rejects_post
    owner = random_author
    soalition = Soalitions.new(login: owner).create('hey you', '#', '-')
    post = soalition.share(random_author, '#')
    assert(!post.approved?)
    assert_raises do
      post.reject('stranger')
    end
    post.reject(owner)
  end

  def test_adds_reposts
    owner = random_author
    soalition = Soalitions.new(login: owner).create('hey you', '#', '-')
    post = soalition.share(random_author, '#')
    post.repost(random_author, '#')
  end
end
