# frozen_string_literal: true

# Copyright (c) 2023 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'time'

system 'git add .'
system "git commit -m 'Update #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}.'"
system 'git pull'
system 'git push'
