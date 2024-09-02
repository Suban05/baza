#!/bin/bash
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

set -ex

cd "$(dirname "$0")"

trap 'shutdown' EXIT

PATH=$(pwd):$PATH

{{ save_files }}

mkdir .ssh
mv id_rsa .ssh/id_rsa
chmod 600 .ssh/id_rsa

ls -al .

aws ecr get-login-password --region "{{ region }}" | docker login --username AWS --password-stdin "{{ repository }}"

uri="git@github.com:{{ github }}.git"
if [ ! -s ~/.ssh/id_rsa ]; then
  uri="https://github.com/{{ github }}"
fi
git clone -b "{{ branch }}" --depth=1 --single-branch "${uri}" swarm
head=$(git --git-dir swarm/.git rev-parse HEAD)

printf '0' > exit.txt
docker build baza -t baza --platform linux/amd64 2>&1 > docker.log || echo $? > exit.txt
code=$(cat exit.txt)

if [ "${code}" == '0' ]; then
  docker tag baza "{{ repository }}/{{ image }}"
  docker push "{{ repository }}/{{ image }}"

  func="baza-{{ name }}"
  if ! aws lambda get-function --function-name "${func}"; then
    aws lambda create-function --function-name "${func}"
    # configure S3 to send events there
    # give this function permissions to work with S3 bucket
  fi
  aws lambda update-function-code --function-name "${func}" --image-uri "{{ repository }}/{{ image }}" --publish
fi

curl -X PUT -d docker.log -H 'Content-Type: text/plain' "https://www.zerocracy.com/?secret={{ secret }}&head=${head}&exit=${code}"
