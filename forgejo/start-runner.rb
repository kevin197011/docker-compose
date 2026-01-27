#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

runner_data_dir = File.join(__dir__, 'data', 'runner')
runner_file = File.join(runner_data_dir, '.runner')

unless File.exist?(runner_file)
  puts "❌ 错误: Runner 尚未注册"
  puts ""
  puts "请先运行注册脚本："
  puts "  ./register-runner.sh"
  exit 1
end

puts "启动 Forgejo Runner 服务..."
system('docker', 'compose', 'up', '-d', 'forgejo-runner')

if $?.success?
  puts "✅ Runner 服务已启动"
  puts ""
  puts "查看日志: docker compose logs -f forgejo-runner"
else
  puts "❌ Runner 服务启动失败"
  exit 1
end
