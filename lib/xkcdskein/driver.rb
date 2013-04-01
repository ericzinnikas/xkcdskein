module XkcdSkein
  RANGE         = [*'0'..'9', *'a'..'z', *'A'..'Z']
  RANDALL_DATA  = "5b4da95f5fa08280fc9879df44f418c8f9f12ba424b7757de02bbdfbae0d4c4fdf9317c80cc5fe04c6429073466cf29706b8c25999ddd2f6540d4475cc977b87f4757be023f19b8f4035d7722886b78869826de916a79cf9c94cc79cd4347d24b567aa3e2390a573a373a48a5e676640c79cc70197e1c5e7f902fb53ca1858b6"
  RANDALL_HEX   = RANDALL_DATA.hex
  SKEIN         = SkeinR::Hash1024.new(1024)

  @overall      = 500
  @best_data    = nil

  def self.print_instructions
    puts
    puts "*******XKCD Skein Generator for UMD*******"
    puts "If the lowest number of wrong bits is lower than umd.edu's current record at http://almamater.xkcd.com/best.csv"
    puts "Then you, the user, should go submit the input string, at http://almamater.xkcd.com/?edu=umd.edu"
    puts "******************************************"
    puts
  end

  def self.bit_wrongness str
    n       = str.hex ^ RANDALL_HEX
    matches = 0

    while n != 0
      n &= n - 1
      matches += 1
    end

    matches
  end

  def self.skein_hash str
    skein = deep_copy SKEIN
    skein.update_str(str)
    SkeinR::bytes_to_hex(skein.final)
  end

  def self.run_once n = nil
    n     ||= Array.new(rand(16)+8) { RANGE.sample }.join
    lowest  = bit_wrongness(skein_hash(n))

    if lowest < @overall
      @best_data = n
      @overall   = lowest

      return [n, lowest]
    else
      return nil
    end
  end

  def self.deep_copy obj
    new_obj = obj.dup

    obj.instance_variables.each do |var|
      begin
        new_obj.instance_variable_set(var, obj.instance_variable_get(var).dup)
      rescue TypeError
        # Some object don't .dup at all, like Fixnums, just ignore those.
      end
    end

    new_obj
  end
end
