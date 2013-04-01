libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require "SkeinR"

def main
  puts
  puts "*******XKCD Skein Generator for UMD*******"
  puts "If the lowest number of wrong bits is lower than umd's current record at http://almamater.xkcd.com/best.csv"
  puts "Then you, the user, should go submit the input string, at http://almamater.xkcd.com/?edu=umd.edu"
  puts "******************************************"
  puts
   
  range = [*'0'..'9', *'a'..'z', *'A'..'Z']
  overall = 500
  best_data = nil
  randall_data = "5b4da95f5fa08280fc9879df44f418c8f9f12ba424b7757de02bbdfbae0d4c4fdf9317c80cc5fe04c6429073466cf29706b8c25999ddd2f6540d4475cc977b87f4757be023f19b8f4035d7722886b78869826de916a79cf9c94cc79cd4347d24b567aa3e2390a573a373a48a5e676640c79cc70197e1c5e7f902fb53ca1858b6"

  while (n = Array.new(rand(25)+8){range.sample}.join) do
    skein = SkeinR::Hash1024.new(1024)
    skein.update_str n
    res = SkeinR::bytes_to_hex(skein.final).downcase

    arr1 = res.hex.to_s(2).rjust(1024, '0').split("")
    arr2 = randall_data.hex.to_s(2).rjust(1024, '0').split("")
    match = 0
    1.upto(arr1.length) do |i|
      if arr1[i] == arr2[i]
        match += 1
      end
    end

    lowest = 1024 - match
    
    if lowest < overall
      best_data = n
      overall = lowest
      puts "Input string: #{n}"
      puts "Lowest number of wrong bits: #{lowest}\n\n"
    end
  end
end

main
