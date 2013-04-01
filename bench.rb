require_relative 'lib/xkcdskein'

N       = 1000
start   = Time.now

N.times { XkcdSkein.run_once }

elapsed = Time.now - start

puts "Ran #{N} iterations in #{elapsed.round(2)} seconds. " +
  "#{(N / elapsed).round(2)}/s."
