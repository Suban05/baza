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

require 'zlib'
require_relative '../objects/baza/urror'

# Take a job that needs processing (or return 204 if no job).
get '/pop' do
  admin_only
  owner = params[:owner]
  raise Baza::Urror, 'The "owner" is a mandatory query param' if owner.nil?
  pipe = settings.humans.pipe(settings.fbs)
  job = pipe.pop(owner)
  if job.nil?
    status 204
    return
  end
  content_type('application/zip')
  Tempfile.open do |f|
    pipe.pack(job, f.path)
    File.binread(f.path)
  end
end

# Put back the result of its processing (the body is a ZIP file).
put '/finish' do
  admin_only
  id = params[:id]
  raise Baza::Urror, 'The "id" is a mandatory query param' if id.nil?
  job = settings.humans.job_by_id(id)
  pipe = settings.humans.pipe(settings.fbs)
  Tempfile.open do |f|
    request.body.rewind
    File.binwrite(f.path, request.body.read)
    pipe.unpack(job, f.path)
  end
  "Job ##{job.id} finished, thanks!"
end
