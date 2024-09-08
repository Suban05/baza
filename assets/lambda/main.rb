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

require 'backtrace'
require 'iri'
require 'typhoeus'

# This is needed because of this: https://github.com/aws/aws-lambda-ruby-runtime-interface-client/issues/14
require 'aws_lambda_ric'
require 'io/console'
require 'stringio'
module AwsLambdaRuntimeInterfaceClient
  class LambdaRunner
    def send_error_response(lambda_invocation, err, exit_code = nil, runtime_loop_active = true)
      error_object = err.to_lambda_response
      @lambda_server.send_error_response(
        request_id: lambda_invocation.request_id,
        error_object: error_object,
        error: err,
        xray_cause: XRayCause.new(error_object).as_json
      )
      @exit_code = exit_code unless exit_code.nil?
      @runtime_loop_active = runtime_loop_active
    end
  end
end

def register(stdout, job)
  home = Iri.new('https://www.zerocracy.com')
    .append('swarms')
    .append('{{ swarm }}'.to_i)
    .append('invocation')
    .add(secret: '{{ secret }}')
  Typhoeus::Request.put(
    (job.nil? ? home : home.add(job: job)).to_s,
    connecttimeout: 30,
    timeout: 300,
    body: stdout,
    headers: {
      'Content-Type' => 'text/plain',
      'Content-Length' => stdout.length
    }
  )
end

at_exit do
  register(Backtrace.new($!), 0)
end

def go(event:, context:)
  stdout = `/bin/bash /swarm/entry.sh 2>&1`
  register(stdout, nil)
  'Done!'
end

