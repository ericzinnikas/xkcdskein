require "bundler"
Bundler.setup(:default, :test)

require 'rspec/core/rake_task'

task :default => [:test]

desc "Run all tests"
RSpec::Core::RakeTask.new(:test) do |t|
  t.rspec_opts = '-cfs'
end

desc 'Run benchmark'
task :bench do
  exec "ruby bench.rb"
end

desc 'Run the main executable parallelized'
task :parallel, :processes do |t, args|
  (args[:processes] || 4).to_i.times { fork { exec './bin/main' } }
  Process.waitall
end
