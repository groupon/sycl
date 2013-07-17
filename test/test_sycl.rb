# test_sycl.rb - simple regression tests for Sycl library
# Andrew Ho (ho@groupon.com)
#
# Copyright (c) 2012, Groupon, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# Neither the name of GROUPON nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'test/unit'
require 'sycl'

class SyclTest < Test::Unit::TestCase
  def test_basic
    d = Sycl::load(<<-'end')
      username: andrew
      name: Andrew Ho
      email: ho@groupon.com
      work_experience:
        groupon:
          company_name: Groupon, Inc.
          website: http://www.groupon.com/
          position: Senior Software Developer
          start_date: 2010-08-01
        tellme:
          company_name: Tellme Networks, Inc.
          website: http://www.tellme.com/
          position: Senior Software Engineer
          start_date: 2000-02-08
          end_date: 2010-06-30
      pets:
        cats:
        - moy
        - momo
        birds:
        - pico
    end
    assert_equal d['username'], 'andrew'
    assert_equal d.name, 'Andrew Ho'
    assert_equal d.keys.sort * ',', 'email,name,pets,username,work_experience'
    assert_equal d.work_experience.keys.sort * ',', 'groupon,tellme'
    assert_equal d.work_experience.groupon.company_name, 'Groupon, Inc.'
    assert_equal d['pets']['cats'], %w{moy momo}
  end

  def test_arrays_sorted_by_default
    sample = Sycl::load <<-EOS
      elements:
      - foo
      - bar
    EOS
    parsed = Sycl::load sample.to_yaml
    assert_equal parsed.elements, ['bar', 'foo']
  end

  def test_arrays_with_no_default_sorting
    Sycl::Array.default_sorting = false
    sample = Sycl::load <<-EOS
      elements:
      - foo
      - bar
    EOS
    parsed = Sycl::load sample.to_yaml
    assert_equal parsed.elements, ['foo', 'bar']
    Sycl::Array.default_sorting = true
  end

  def test_render_unsorted
    sample = Sycl::load <<-EOS
      elements:
      - foo
      - bar
      others:
      - bbb
      - aaa
    EOS
    sample.others.render_unsorted!
    parsed = Sycl::load sample.to_yaml
    assert_equal parsed.elements, ['bar', 'foo']
    assert_equal parsed.others, ['bbb', 'aaa']
  end

  def test_render_sorted
    Sycl::Array.default_sorting = false
    sample = Sycl::load <<-EOS
      elements:
      - foo
      - bar
      others:
      - bbb
      - aaa
    EOS
    sample.others.render_sorted!
    parsed = Sycl::load sample.to_yaml
    assert_equal parsed.elements, ['foo', 'bar']
    assert_equal parsed.others, ['aaa', 'bbb']
    Sycl::Array.default_sorting = true
  end

  def test_hash_sort
    d = Sycl::load(<<-'end')
      users:
      - username: bob
        uid: 1002
        homedir: /home/bob
      - username: alice
        uid: 1003
        homedir: /home/alice
      - username: charlie
        uid: 1001
        homedir: /home/charlie
      - username: aaron
        uid: 500
        homedir: /var/tmp/aaron
    end
    d.users.render_sorted!
    d2 = YAML::load d.to_yaml
    users = d2['users']
    assert_equal users.size, 4
    assert_equal 'alice', users.first['username']
    assert_equal 'aaron', users[-1]['username']
  end
end
