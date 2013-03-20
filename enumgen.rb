require 'cpp_write'

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
  dsl_accessor :filename, :namespace, :values
  attr_reader :name
  def initialize(name)
    @name = name
  end
end

class Enumgen
  def enum(name, &block)
    e = Enum.new(name)
    e.instance_eval(&block)
    cpp_write(e)
  end
end

eg = Enumgen.new
lines = IO.read('enumtest.rb')
eg.instance_eval(lines)
