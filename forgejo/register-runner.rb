#!/usr/bin/env ruby
# frozen_string_literal: true
# encoding: utf-8

require 'fileutils'

# 加载环境变量
env_file = File.join(__dir__, '.env')
if File.exist?(env_file)
  File.readlines(env_file, encoding: 'utf-8').each do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')
    
    key, value = line.split('=', 2)
    ENV[key] = value if key && value
  end
end

# 检查必要的环境变量
token = ENV['FORGEJO_RUNNER_REGISTRATION_TOKEN']
instance_url = ENV['FORGEJO_INSTANCE_URL'] || 'http://forgejo:3000'
runner_name = ENV['FORGEJO_RUNNER_NAME'] || 'forgejo-runner'
runner_labels = ENV['FORGEJO_RUNNER_LABELS'] || 'ubuntu-latest:docker://node:20-bookworm,ubuntu-22.04:docker://node:20-bookworm'

if token.nil? || token.empty?
  puts "❌ 错误: FORGEJO_RUNNER_REGISTRATION_TOKEN 未设置"
  puts ""
  puts "请按以下步骤获取全局 Runner 注册令牌："
  puts "1. 访问 Forgejo Web 界面: http://localhost:3000"
  puts "2. 登录管理员账户"
  puts "3. 进入: Site administration > Actions > Runners"
  puts "4. 点击 'Create new Runner'，选择 'Global' 范围"
  puts "5. 复制注册令牌"
  puts "6. 在 .env 文件中设置: FORGEJO_RUNNER_REGISTRATION_TOKEN=你的令牌"
  puts ""
  puts "或者运行以下命令生成令牌："
  puts "  docker exec forgejo forgejo forgejo-cli actions generate-runner-token"
  exit 1
end

puts "=========================================="
puts "注册 Forgejo Runner"
puts "=========================================="
puts "实例 URL: #{instance_url}"
puts "Runner 名称: #{runner_name}"
puts "Runner 标签: #{runner_labels}"
puts "=========================================="

# 检查 runner 数据目录
runner_data_dir = File.join(__dir__, 'data', 'runner')
FileUtils.mkdir_p(runner_data_dir)

# 检查是否已注册
runner_file = File.join(runner_data_dir, '.runner')
if File.exist?(runner_file)
  puts "⚠️  警告: Runner 已注册（.runner 文件已存在）"
  puts "如需重新注册，请先删除: #{runner_file}"
  exit 0
end

# 执行注册命令
puts "开始注册 Runner..."
cmd = [
  'docker', 'run', '--rm',
  '--network', 'forgejo_net',
  '-v', "#{File.expand_path(runner_data_dir)}:/data",
  '--entrypoint', 'forgejo-runner',
  'code.forgejo.org/forgejo/runner:12',
  'register',
  '--instance', instance_url,
  '--token', token,
  '--name', runner_name,
  '--labels', runner_labels,
  '--no-interactive'
]

system(*cmd)

if $?.success?
  puts "✅ Runner 注册成功！"
  puts ""
  puts "下一步："
  puts "1. 启动 Runner 服务: docker compose up -d forgejo-runner"
  puts "2. 查看 Runner 日志: docker compose logs -f forgejo-runner"
else
  puts "❌ Runner 注册失败"
  exit 1
end
