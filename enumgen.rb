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
  dsl_accessor :filename, :namespace, :values, :storage_type, :code, :default_value, :extra_includes
  attr_reader :name
  def initialize(name)
    @name = name
    @filename = @name
  end
end

class Enumgen
  def enum(name, &block)
    e = Enum.new(name)
    e.instance_eval(&block)
    begin
      cpp_write(e)
    rescue Exception => e
      raise "Error with enum #{name}: #{e}"
    end
  end
end

if $0 == __FILE__
  begin
    eg = Enumgen.new
    ARGV.each { |file|
      lines = IO.read(file)
      eg.instance_eval(lines)
    }
  rescue Exception => e
    puts e
  end
end
