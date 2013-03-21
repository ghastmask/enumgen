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

def extra_interface_includes(enum)
  [*enum.interface_includes].map { |val| "#include #{val}" }.join("\n")
end

def extra_implementation_includes(enum)
  [*enum.implementation_includes].map { |val| "#include #{val}" }.join("\n")
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

  fully_qualified_name =
    (enum.namespace ? enum.namespace + "::" : '') + enum.name

  fq_name_token = fully_qualified_name.tr(":","_");

  hpp =
%{#ifndef #{header_guard}
#define #{header_guard}

#include <cstdint>
#include <iosfwd>
#include <string>
#{extra_interface_includes(enum)}

#{namespace_open}

enum class #{enum.name} #{enum.storage_type ? ": #{enum.storage_type}" : ""}
{
    #{values.map { |k,v|
      v.class == String ? "#{k}='#{v}'" : "#{k}=#{v}"
    }.join(",\n      ")
  }
};

template <class Enum> Enum name_to_value(std::string const &);

std::string const & value_to_name(#{enum.name});

#{enum.interface_code}

std::ostream & operator<<(std::ostream &, #{enum.name});
std::istream & operator>>(std::istream &, #{enum.name} &);

//--

namespace detail {
  #{enum.name} #{fq_name_token}_name_to_value(std::string const &);
}

template <>
inline
#{enum.name} name_to_value(std::string const & name)
{
  return detail::#{fq_name_token}_name_to_value(name);
}
 
#{namespace_close}
#endif
}

  cpp = %{
#include "#{enum.filename}.hpp"
#include <iostream>
#include <map>
#include <stdexcept>
#{extra_implementation_includes(enum)}

#{namespace_open}

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
  build_type_map()
  {
    Types type;
#{values.map { |k,v|
  "    type[\"#{k}\"] = #{fully_qualified_name}::#{k};"
  }.join("\n")
}
    return type;
  }

  Types types_map = build_type_map();

}

namespace detail {
  #{enum.name} #{fq_name_token}_name_to_value(std::string const & name)
  {
    auto i = types_map.find(name);
    if(i == types_map.end())
    {
       throw std::runtime_error("'" + name + "' is not a valid value.");
    }
    else
    {
      return i->second;
    }
  }
}

  std::string const &
  value_to_name(#{enum.name} v)
  {
    switch (v)
    {
      #{i=-1; values.map { |k,v|
        "case #{enum.name}::#{k}: return names[#{i+=1}];"
      }.join("\n      ")}
    }
    return names[#{values.length-1}];
  }

  std::ostream &
  operator<<(std::ostream & os, #{enum.name} v)
  {
    return os << value_to_name(v);
  }

  std::istream &
  operator>>(std::istream & is, #{enum.name} & v)
  {
    std::string tmp;
    is >> tmp;
    v = name_to_value<#{enum.name}>(tmp);
    return is;

  }

#{enum.implementation_code}

#{namespace_close}
  }

  File.open(enum.filename + ".hpp", "w") {|f| f.write(hpp)}
  File.open(enum.filename + ".cpp", "w") {|f| f.write(cpp)}
end
