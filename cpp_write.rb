require 'set'

# Fixes up single values and arrays of values to give them indexes
# Changes hash to sorted array of [key,value] tuples
# returns the sorted array of [[enum value, name],..]
def convert_values(values)
  values_hash = {}
  if(values.class != Hash)
    values = [*values]
    0.upto(values.length-1) { |index|
      values_hash[values[index]] = index
    }
  else
    values_hash = values
  end

  values_hash.sort_by {|k,v| v}
end

def validate_values(values)
  if(!values)
    raise "No values given."
  end

  return if values.class != Hash

  value_types = Set.new
  values.map { |k,v| 
    value_types.add(v.class)
    if(v.class == String)
      raise "Must use a single character for enum values" if v.length != 1
    end
  }
  if(value_types.length != 1)
    raise "Only one type of value allowed in enum, found: #{value_types.to_a.join(", ")}"
  end
end

def cpp_write(enum)
  validate_values(enum.values)
  
  namespace_open = enum.namespace.split("::").map { |name|
    "namespace #{name} {"
  }.join("\n")
  namespace_close = enum.namespace.split("::").map { "}" }.join(" ")
  header_guard = enum.namespace.split("::").map { |name|
    "#{name}"
  }.join("__") + "__" + enum.name + "__hpp"

  values = convert_values(enum.values)

  hpp = %{
#ifndef #{header_guard}
#define #{header_guard}

##include <cstdint>
#include <string>

#{namespace_open}

class #{enum.name}
{
public:
  enum class raw #{enum.storage_type ? ": #{enum.storage_type}" : ""}
  {
      #{values.map { |k,v|
        v.class == String ? "#{k}='#{v}'" : "#{k}=#{v}"
      }.join(",\n      ")
    }
  };

  #{enum.name}();
  #{enum.name}(#{enum.name} const &);
  #{enum.name}(raw val);

  #{enum.name} & operator=(#{enum.name} const &);
  #{enum.name} & operator=(#{enum.name}::raw);

#{values.map { |k,v|
  "  static #{enum.name} const #{k};"
}.join("\n")}

  raw value() const;
  std::string const & name() const;

  static #{enum.name} name_to_value(std::string const &);
  static std::string const & value_to_name(#{enum.name});

private:
  raw value_;
};

bool operator==(#{enum.name}, #{enum.name});
bool operator==(#{enum.name}::raw, #{enum.name});
bool operator!=(#{enum.name}, #{enum.name});
bool operator!=(#{enum.name}::raw, #{enum.name});

std::ostream & operator<<(std::ostream &, #{enum.name});
std::istream & operator>>(std::istream &, #{enum.name} &);

//--

inline
#{enum.name}::raw
#{enum.name}::
value() const
{
  return value_;
}

#{namespace_close}
#endif
}

  fully_qualified_name =
    (enum.namespace ? enum.namespace + "::" : '') + enum.name
  cpp = %{
#include "#{enum.filename}.hpp"
#include <iostream>
#include <map>

#{namespace_open}

#{values.map { |k,v|
  "  #{enum.name} const #{enum.name}::#{k}(#{enum.name}::raw::#{k});"
}.join("\n")}
namespace
{
  std::string const names[] =
  {
#{values.map { |k,v|
  "    \"#{k}\""
}.join(",\n")}
  };

  typedef std::map<std::string, #{fully_qualified_name}> Types;
  Types
  get_type_map()
  {
    Types type;
#{values.map { |k,v|
  "    type[\"#{k}\"] = #{fully_qualified_name}::#{k};"
  }.join("\n")
}
    return type;
  }

  Types types_map = get_type_map();
}


  std::string const &
  #{enum.name}::
  value_to_name(#{enum.name} v)
  {
    switch (v.value())
    {
      #{i=-1; values.map { |k,v|
        "case #{enum.name}::raw::#{k}: return names[#{i+=1}];"
      }.join("\n      ")}
    }
    return names[#{values.length-1}];
  }

  #{enum.name}
  #{enum.name}::
  name_to_value(std::string const & name)
  {
    Types::iterator i = types_map.find(name);
    if(i == types_map.end())
    {
      return #{enum.name}::INVALID_;
    }
    else
    {
      return i->second;
    }
  }

  std::string const &
  #{enum.name}::
  name() const
  {
    return value_to_name(this->value());
  }

  #{enum.name}::
  #{enum.name}()
  : value_(raw::INVALID_)
  {
  }

  #{enum.name}::
  #{enum.name}(#{enum.name} const & other)
  : value_(other.value())
  {
  }

  #{enum.name}::
  #{enum.name}(raw v)
  : value_(v)
  {
  }

  #{enum.name} &
  #{enum.name}::
  operator=(#{enum.name} const & other)
  {
    value_ = other.value();
    return *this;
  }

  #{enum.name} &
  #{enum.name}::
  operator=(#{enum.name}::raw other)
  {
    value_ = other;
    return *this;
  }

  bool operator==(#{enum.name} lhs, #{enum.name} rhs)
  {
    return lhs.value() == rhs.value();
  }

  bool operator==(#{enum.name}::raw lhs, #{enum.name} rhs)
  {
    return lhs == rhs.value();
  }

  bool operator!=(#{enum.name} lhs, #{enum.name} rhs)
  {
    return !(lhs == rhs);
  }

  bool operator!=(#{enum.name}::raw lhs, #{enum.name} rhs)
  {
    return !(lhs == rhs);
  }

  std::ostream &
  operator<<(std::ostream & os, #{enum.name} v)
  {
    return os << v.name();
  }

  std::istream &
  operator>>(std::istream & is, #{enum.name} & v)
  {
    std::string tmp;
    is >> tmp;
    v = #{enum.name}::name_to_value(tmp);
    return is;
    
  }

#{namespace_close}
  }
  
  File.open(enum.filename + ".hpp", "w") {|f| f.write(hpp)} 
  File.open(enum.filename + ".cpp", "w") {|f| f.write(cpp)} 
end
