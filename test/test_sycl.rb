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
end
