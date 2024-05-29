# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/humans'
require_relative '../../objects/baza/factbases'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::JobTest < Minitest::Test
  def test_starts
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    id = token.start(test_name, test_name).id
    job = human.jobs.get(id)
    assert(job.id.positive?)
    assert_equal(id, job.id)
    assert(!job.finished?)
    assert(!job.created.nil?)
  end

  def test_cant_finish_twice
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    job = token.start(test_name, test_name)
    assert(!job.finished?)
    job.finish!(test_name, 'stdout', 0, 544)
    assert_raises do
      job.finish!(test_name, 'another stdout', 0, 11)
    end
  end

  def test_expires_once
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    job = token.start(test_name, test_name)
    assert(!job.expired?)
    job.expire!(Baza::Factbases.new('', ''))
    assert(job.expired?)
    assert_raises do
      job.expire!
    end
  end
end
