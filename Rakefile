# frozen_string_literal: true

# Copyright (c) 2023 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'erb'
require 'time'

task default: %w[push]

task :push do
  Rake::Task[:fmt].invoke
  system 'git add .'
  system "git commit -m 'Update #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}.'"
  system 'git pull'
  system 'git push'
end

task :fmt do
  system 'yamlfmt .'
end

task :new do
  $stdout.print 'app name: '
  @app_name = $stdin.gets.strip
  Dir.mkdir @app_name
  File.open("#{@app_name}/compose.yml", 'w') { |f| f.write(ERB.new(File.open('compose.yml.erb').read).result(binding)) }
  puts "docker compose #{@app_name} created."
end
