require_relative 'cpp_write'

class Module
  def dsl_accessor(*symbols)
    symbols.each { |sym|
      class_eval %{
        def #{sym}(*val)
          if(val.empty?)
            @#{sym}
          else
            @#{sym} = val.size == 1 ? val[0] : val
          end
        end
      }
    }
  end
end

class Enum
  dsl_accessor :filename, :namespace, :values, :storage_type,
               :interface_code, :implementation_code,
               :interface_includes, :implementation_includes
  attr_reader :name
  def initialize(name)
    @name = name
    @filename = @name
  end
end

class Enumgen
  attr_reader :enums
  def initialize
    @enums = []
  end

  def enum(name, &block)
    e = Enum.new(name)
    e.instance_eval(&block)
    @enums << e
  end
end

if $0 == __FILE__
  begin
    eg = Enumgen.new
    ARGV.each { |file|
      lines = IO.read(file)
      eg.instance_eval(lines)
    }

    eg.enums.each { |e|
      cpp_writer = Cpp_Writer.new(e)
      cpp_writer.write()
    }

  rescue Exception => e
    puts e
  end
end
