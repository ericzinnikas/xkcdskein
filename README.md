# xkcdskein
Generates random strings, then runs them through a Skein 1024 1024 hash, and tests the number of bits correct vs. Randall's current hash at [almamater.xkcd.com](http://almamater.xkcd.com). The comparison hash value is currently hardcoded, not scraped, so if it changes, you'll need to pull the repo again!

## Instructions
Clone this repo, then run 

```
ruby driver.rb`
```

If the lowest number of wrong bits is lower than umd's current record at [almamater.xkcd.com/best.csv](http://almamater.xkcd.com/best.csv), then you should go submit the input string, at [almamater.xkcd.com/?edu=umd.edu](http://almamater.xkcd.com/?edu=umd.edu)

## Bugs
It will occasionally be off by a bit or two. Currently debugging. Seems to only occur very, very rarely. Perhaps only for strings input strings less than 8 in length, which have been removed.

## Help!
UMD students, please feel free to bugfix, increase efficiency, or whatever else, then submit a pull request!

## Credit & Thanks
Thank you to www.coderslagoon.com for the SkeinR library for Skein hashing in Ruby!
