# xkcdskein
Generates random strings, then runs them through a Skein 1024 1024 hash, and tests the number of bits correct vs. Randall's current hash at http://almamater.xkcd.com/ (currently hardcoded!)

## Instructions
Pull it, then run `ruby driver.rb`
If "lowest" is lower than umd.edu's current record at http://almamater.xkcd.com/best.csv, then submit the Input!

## Bugs
It will occasionally be off by a bit or two. Currently debugging.

## Help!
UMD students, please feel free to bugfix, increase efficiency, or whatever else, then submit a pull request!
