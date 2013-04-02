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

class Cpp_Writer

  def initialize(enum)
    @enum = enum
    validate_values(@enum.values)
    @values = convert_values(@enum.values)
  end

  def extra_interface_includes
    [*@enum.interface_includes].map { |val| "#include #{val}" }.join("\n")
  end

  def extra_implementation_includes
    [*@enum.implementation_includes].map { |val| "#include #{val}" }.join("\n")
  end

  def open_namespace
    namespace_open = @enum.namespace.split("::").map { |name|
      "namespace #{name} {"
    }.join("\n")
  end

  def close_namespace
    namespace_close = @enum.namespace.split("::").map { "}" }.join(" ")
  end

  def header_guard_begin
    header_guard = @enum.namespace.split("::").map { |name|
      "#{name}"
    }.join("__") + "__" + @enum.name + "__hpp"

    "#ifndef #{header_guard}\n#define #{header_guard}"
  end

  def header_guard_end
    "#endif"
  end

  def interface_includes
    ["cstdint", "stdexcept", "map", "iosfwd", "string"].map { |file|
      "#include <#{file}>"
    }.join("\n")
  end

  def enum_class
    %Q{enum class #{@enum.name} #{@enum.storage_type ? ": #{@enum.storage_type}" : ""}
{
    #{@values.map { |k,v|
      v.class == String ? "#{k}='#{v}'" : "#{k}=#{v}"
    }.join(",\n    ")
    }
};}
  end

  def stream_interfaces
    "std::ostream & operator<<(std::ostream &, #{@enum.name});\n" +
    "std::istream & operator>>(std::istream &, #{@enum.name} &);"
  end

  def string_conversion_interfaces
    "template <class Enum> Enum name_to_value(std::string const &);\n" +
    "std::string const & value_to_name(#{@enum.name});"
  end

  def fully_qualified_name
    fully_qualified_name =
      (@enum.namespace ? @enum.namespace + "::" : '') + @enum.name
  end

  def fq_name_token
    fq_name_token = fully_qualified_name.tr(":","_");
  end

  def name_to_value_exception
     %Q{throw std::runtime_error("'" + name + "' is not a valid value.");}
  end

  def name_to_value_impl
    %Q{
template <>
inline
#{@enum.name}
name_to_value(std::string const & name)
{
  using namespace detail::#{@enum.name}_enum;
  auto i = std::lower_bound(
      types_map,
      types_map_end,
      name,
      [] (Type_Map const & m, std::string const & n)  { return m.first < n; });
  if(i != types_map_end && i->first == name)
  {
    return i->second;
  }
  else
  {
     #{name_to_value_exception}
  }
}}
  end

  def auto_gen_warning
"/**
 * WARNING WARNING WARNING WARNING WARNING WARNING WARNING
 *   THIS FILE WAS AUTOMATICALLY GENERATED BY ENUMGEN
 *              DO NOT MODIFY DIRECTLY
 * WARNING WARNING WARNING WARNING WARNING WARNING WARNING
 */"
  end

  def section_spacing
    "\n\n"
  end

  def interface_code
    @enum.interface_code
  end

  def header_file
    hpp = ""
    hpp += header_guard_begin + section_spacing
    hpp += auto_gen_warning + section_spacing
    hpp += interface_includes + section_spacing
    hpp += extra_interface_includes + section_spacing
    hpp += open_namespace + section_spacing
    hpp += enum_class + section_spacing
    hpp += string_and_value_holders + section_spacing
    hpp += string_conversion_interfaces + section_spacing
    hpp += stream_interfaces + section_spacing
    hpp += interface_code + section_spacing
    hpp += name_to_value_impl + section_spacing
    hpp += value_to_name_impl + section_spacing
    hpp += close_namespace + section_spacing
    hpp += header_guard_end
  end

  def implementation_includes
    %Q{#include "#{@enum.filename}.hpp"\n} +
    ["iostream", "map", "stdexcept"].map { |file|
      "#include <#{file}>"
    }.join("\n")
  end

  def type_map
    sorted_values = @values.sort { |a,b| a[0] <=> b[0] }
%Q{namespace detail {
namespace #{@enum.name}_enum {
  std::string const names[] =
  {
    #{@values.map { |k,v|
      "\"#{k}\""
    }.join(",\n    ")}
  };

  Type_Map const types_map[] =
  {
    #{sorted_values.map { |k,v|
    "{\"#{k}\" , #{fully_qualified_name}::#{k} }"
    }.join(",\n    ")
    }
  };

  Type_Map const * types_map_end = types_map + (sizeof(types_map) / sizeof(types_map[0]));

}}}
  end

  def string_and_value_holders
%Q{namespace detail { namespace #{@enum.name}_enum {
  extern std::string const names[];
  typedef std::pair< std::string, #{fully_qualified_name} > Type_Map;
  extern Type_Map const types_map[];
  extern Type_Map const * types_map_end;
}}}
  end

  def value_to_name_exception
    %Q{throw std::runtime_error("Invalid value given for #{@enum.name}");}
  end

  def value_to_name_impl
  %Q{
inline
std::string const &
value_to_name(#{@enum.name} v)
{
  switch (v)
  {
  #{i=-1; @values.map { |k,v|
  "  case #{@enum.name}::#{k}: return detail::#{@enum.name}_enum::names[#{i+=1}];"
  }.join("\n      ")}
  }
  #{value_to_name_exception}
}}
  end

  def stream_implementations
  %Q{
std::ostream &
operator<<(std::ostream & os, #{@enum.name} v)
{
  return os << value_to_name(v);
}

std::istream &
operator>>(std::istream & is, #{@enum.name} & v)
{
  std::string tmp;
  is >> tmp;
  v = name_to_value<#{@enum.name}>(tmp);
  return is;

}}

  end

  def implementation_code
    @enum.implementation_code
  end

  def cpp_file
    cpp = ""
    cpp += implementation_includes + section_spacing
    cpp += auto_gen_warning + section_spacing
    cpp += extra_implementation_includes + section_spacing
    cpp += open_namespace + section_spacing
    cpp += type_map + section_spacing
    cpp += stream_implementations + section_spacing
    cpp += implementation_code + section_spacing
    cpp += close_namespace
  end

  def write
    File.open(@enum.filename + ".hpp", "w") {|f| f.write(header_file)}
    File.open(@enum.filename + ".cpp", "w") {|f| f.write(cpp_file)}
  end

end
