# = sycl.rb - Simple YAML Configuration Library
#
# For more details, visit the
# {Sycl GitHub page}[https://github.com/groupon/sycl/"target="_parent].
#
# == License
#
# Copyright (c) 2012, Groupon, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# Neither the name of GROUPON nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'yaml'

# = sycl.rb - Simple YAML Configuration Library
#
# Sycl is a gem that makes using YAML[http://yaml.org/] for
# configuration files convenient and easy. Hashes and arrays made from
# parsing YAML via Sycl get helper methods that provide simple and natural
# syntax for querying and setting values. YAML output through Sycl is
# sorted, so configuration file versions can be compared consistently, and
# Sycl has hooks to add output styles, so your configuration files stay
# easy for humans to read and edit, even after being parsed and
# re-emitted.
#
# For more details, visit the
# {Sycl GitHub page}[https://github.com/groupon/sycl/"target="_parent].

module Sycl

  # Sycl::load(yaml) is the Sycl counterpart to YAML::load(yaml). It
  # accepts YAML text, and returns a Sycl::Hash or Sycl::Array object
  # representing the parsed YAML.

  def self.load(yaml)
    from_object YAML::load(yaml)
  end

  # Sycl::load(filename) is the Sycl counterpart to
  # YAML::load_file(filename). It accepts a filename, and returns a
  # Sycl::Hash or Sycl::Array object representing the parsed YAML from
  # that file.

  def self.load_file(filename)
    from_object YAML::load_file(filename)
  end

  # Sycl::dump(object) is the Sycl counterpart to YAML::dump(object). It
  # takes a Sycl::Hash or a Sycl::Array, and renders it as YAML. Sycl
  # YAML output is always sorted in canonical order, so you can parse
  # and re-emit data in a reliable way.

  def self.dump(object)
    if (object.is_a?(::Hash)  && !object.is_a?(Sycl::Hash)) ||
       (object.is_a?(::Array) && !object.is_a?(Sycl::Array))
      sycl_version = from_object object
      sycl_version.to_yaml
    else
      object.to_yaml
    end
  end

  private

  def self.from_object(o)
    if o.is_a?(::Hash)
      Sycl::Hash.from_hash(o)
    elsif o.is_a?(::Array)
      Sycl::Array.from_array(o)
    else
      o
    end
  end


  # A Sycl::Array is like an Array, but creating one from an array
  # blesses any child Array or Hash objects into Sycl::Array or
  # Sycl::Hash objects. All the normal Array methods are supported,
  # and automatically promote any inputs into Sycl equivalents. The
  # following example illustrates this:
  #
  #   h = { 'a' => { 'b' => 'Hello, world!' } }
  #   a = Sycl::Array.new
  #   a << h
  #
  #   puts a.first.a.b   # outputs 'Hello, world!'
  #
  # A Sycl::Array supports YAML preprocessing and postprocessing, and
  # having individual nodes marked as being rendered in inline style.
  # YAML output is always sorted, unless individual nodes are marked
  # as being rendered unsorted.
  #
  #   a = Sycl::Array.from_array %w{bravo delta charlie alpha}
  #   a.render_inline!
  #   a.yaml_preprocessor { |x| x.each { |e| e.capitalize! } }
  #   a.yaml_postprocessor { |yaml| yaml.sub(/\A---\s+/, '') }
  #
  #   puts a.first    # outputs 'bravo'
  #   puts a.to_yaml  # outputs '[Alpha, Bravo, Charlie, Delta]'

  class Array < ::Array

    @@default_sorting = true

    def initialize(*args)  # :nodoc:
      @yaml_preprocessor = nil
      @yaml_postprocessor = nil
      @yaml_style = nil
      @render_sorted = @@default_sorting
      super
    end

    def self.[](*args)  # :nodoc:
      Sycl::Array.from_array super
    end

    # Like Sycl::load_file(), a shortcut method to create a Sycl::Array
    # from loading and parsing YAML from a file.

    def self.load_file(filename)
      Sycl::Array.from_array YAML::load_file filename
    end

    # Create a Sycl::Array from a normal Array, or, really, any object
    # that supports Enumerable#each(). Every child Array or Hash gets
    # promoted to a Sycl::Array or Sycl::Hash.

    def self.from_array(array)  # :nodoc:
      retval = Sycl::Array.new
      array.each { |e| retval << Sycl::from_object(e) }
      retval
    end

    # Set Default Array Sorting. In some cases we want to instantiate
    # all sycl objects with sorting defaulted to either true or false.
    #
    # Example:
    #
    #   Sycl::Array.default_sorting = false

    def self.default_sorting=(sort)
      @@default_sorting = sort
    end


    # Make sure that if we write to this array, we promote any inputs
    # to their Sycl equivalents. This lets dot notation, styled YAML,
    # and other Sycl goodies continue.

    def []=(*args)  # :nodoc:
      raise ArgumentError => 'wrong number of arguments' unless args.size > 1
      unless args[-1].is_a?(Sycl::Hash) || args[-1].is_a?(Sycl::Array)
        args[-1] = Sycl::from_object(args[-1])
      end
      super
    end

    def <<(e)  # :nodoc:
      unless e.is_a?(Sycl::Hash) || e.is_a?(Sycl::Array)
        e = Sycl::from_object(e)
      end
      super
    end

    def collect!(&block)  # :nodoc:
      super { |o| Sycl::from_object(block.call o) }
    end

    def map!(&block)  # :nodoc:
      super { |o| Sycl::from_object(block.call o) }
    end

    def concat(a)  # :nodoc:
      a = Sycl::Array.from_array(a) unless a.is_a?(Sycl::Array)
      super
    end

    def fill(*args, &block)  # :nodoc:
      raise ArgumentError => 'wrong number of arguments' if args.empty?
      if block_given?
        super { |idx| Sycl::from_object(block.call idx) }
      else
        unless args[0].is_a?(Sycl::Hash) || args[0].is_a?(Sycl::Array)
          args[0] = Sycl::from_object(args[0])
        end
        super
      end
    end

    def insert(i, *args)  # :nodoc:
      raise ArgumentError => 'wrong number of arguments' if args.empty?
      args.collect! do |o|
        unless o.is_a?(Sycl::Hash) || o.is_a?(Sycl::Array)
          o = Sycl::from_object(o)
        end
      end
      super
    end

    def push(*args)  # :nodoc:
      raise ArgumentError => 'wrong number of arguments' if args.empty?
      args.collect! do |o|
        unless o.is_a?(Sycl::Hash) || o.is_a?(Sycl::Array)
          o = Sycl::from_object(o)
        end
      end
      super
    end

    def replace(a)  # :nodoc:
      a = Sycl::Array.from_array(a) unless a.is_a?(Sycl::Array)
      super
    end

    def unshift(*args)  # :nodoc:
      raise ArgumentError => 'wrong number of arguments' if args.empty?
      args.collect! do |o|
        unless o.is_a?(Sycl::Hash) || o.is_a?(Sycl::Array)
          o = Sycl::from_object(o)
        end
      end
      super
    end


    # Make this array, and its children, rendered in inline/flow style.
    # The default is to render arrays in block (multi-line) style.
    #
    # Example:
    #
    #   a = Sycl::Array::from_array %w{one two}
    #   a.yaml_postprocessor { |yaml| yaml.sub(/\A---\s+/, '') }
    #
    #   puts a.to_yaml  # output: "- one\n- two"
    #   a.render_inline!
    #   puts a.to_yaml  # output: '[one, two]'

    def render_inline!
      @yaml_style = :inline
    end

    # Keep rendering this array in block (multi-line) style, but, make
    # this array's children rendered in inline/flow style.
    #
    # Example:
    #
    #   a = Sycl::Array::from_array ['one', {'two' => ['three']}]
    #   a.yaml_postprocessor { |yaml| yaml.sub(/\A---\s+/, '') }
    #
    #   a.render_values_inline!
    #   puts a.to_yaml  # output: "- one\n- two: [three]"
    #   a.render_inline!
    #   puts a.to_yaml  # output: '[one, {two: [three]}]'

    def render_values_inline!
      self.each do |e|
        e.render_inline! if e.respond_to?(:render_inline!)
      end
    end

    # Do not sort this array when it is rendered as YAML. Usually we want
    # elements sorted so that diffs are human-readable, however, there are
    # certain cases where array ordering is significant (for example, a
    # sorted list of queues).

    def render_unsorted!
      @render_sorted = false
    end

    # Sort this array when it is rendered as YAML. Useful when the default_sorting
    # has been set to false and arrays should be sorted.

    def render_sorted!
      @render_sorted = true
    end

    # Set a preprocessor hook which runs before each time YAML is
    # dumped, for example, via to_yaml() or Sycl::dump(). The hook is a
    # block that gets the object itself as an argument. The hook can
    # then set render_inline!() or similar style arguments, prune nil or
    # empty leaf values from hashes, or do whatever other styling needs
    # to be done before a Sycl object is rendered as YAML.

    def yaml_preprocessor(&block)
      @yaml_preprocessor = block if block_given?
    end

    # Set a postprocessor hook which runs after YML is dumped, for
    # example, via to_yaml() or Sycl::dump(). The hook is a block that
    # gets the YAML text string as an argument, and returns a new,
    # possibly different, YAML text string.
    #
    # A common example use case is to suppress the initial document
    # separator, which is just visual noise when humans are viewing or
    # editing a single YAML file:
    #
    #   a.yaml_postprocessor { |yaml| yaml.sub(/\A---\s+/, '') }
    #
    # Your conventions might also prohibit trailing whitespace, which at
    # least the Syck library will tack on the end of YAML hash keys:
    #
    #   a.yaml_postprocessor { |yaml| yaml.gsub(/:\s+$/, '') }

    def yaml_postprocessor(&block)
      @yaml_postprocessor = block if block_given?
    end

    def yaml_preprocess!  # :nodoc:
      @yaml_preprocessor.call(self) if @yaml_preprocessor
    end

    def yaml_postprocess(yaml)  # :nodoc:
      @yaml_postprocessor ? @yaml_postprocessor.call(yaml) : yaml
    end


    # The Psych YAML engine has a bug that results in infinite recursion
    # if to_yaml is over-ridden on a non-native type.  So, we fake out
    # Psych and pretend Sycl::Array is a native type.

    class MockNativeType  # :nodoc:
      def source_location
        ['psych/core_ext.rb']
      end
    end

    def method(sym)  # :nodoc:
      sym == :to_yaml ? MockNativeType.new : super
    end


    # Render this object as YAML. Before rendering, run the object
    # through any yaml_preprocessor() code block. After rendering,
    # filter the YAML text through any yaml_postprocessor() code block.
    #
    # Nodes marked with render_inline!() or render_values_inline!()
    # will be output in flow/inline style, all hashes and arrays will
    # be sorted, and we set a long line width to more or less support
    # line wrap under the Psych library.

    def to_yaml(opts = {})
      yaml_preprocess!
      if defined?(YAML::ENGINE) && YAML::ENGINE.yamler == 'psych'
        opts ||= {}
        opts[:line_width] ||= 999999  # Psych doesn't let you disable line wrap
        yaml = super
      else
        yaml = YAML::quick_emit(self, opts) do |out|
          if @render_sorted
            out.seq(nil, @yaml_style || to_yaml_style) do |seq|
              sort.each { |e| seq.add(e) }
            end
          else
            out.seq(nil, @yaml_style || to_yaml_style) do |seq|
              each { |e| seq.add(e) }
            end
          end
        end
      end
      yaml_postprocess yaml
    end

    if defined?(YAML::ENGINE) && YAML::ENGINE.yamler == 'psych'
      def encode_with(coder)  # :nodoc:
        coder.style = Psych::Nodes::Sequence::FLOW if @yaml_style == :inline
        coder.represent_seq nil, sort
      end
    end

  end


  # A Sycl::Hash is like a Hash, but creating one from an hash blesses
  # any child Array or Hash objects into Sycl::Array or Sycl::Hash
  # objects. All the normal Hash methods are supported, and
  # automatically promote any inputs into Sycl equivalents. The
  # following example illustrates this:
  #
  #   h = Sycl::Hash.new
  #   h['a'] = { 'b' => { 'c' => 'Hello, world!' } }
  #
  #   puts h.a.b.c   # outputs 'Hello, world!'
  #
  # Hash contents can be accessed via "dot notation" (h.foo.bar means
  # the same as h['foo']['bar']). However, h.foo.bar dies if h['foo']
  # does not exist, so get() and set() methods exist: h.get('foo.bar')
  # will return nil instead of dying if h['foo'] does not exist.
  # There is also a convenient deep_merge() that is like Hash#merge(),
  # but also descends into and merges child nodes of the new hash.
  #
  # A Sycl::Hash supports YAML preprocessing and postprocessing, and
  # having individual nodes marked as being rendered in inline style.
  # YAML output is also always sorted by key.
  #
  #   h = Sycl::Hash.from_hash({'b' => 'bravo', 'a' => 'alpha'})
  #   h.render_inline!
  #   h.yaml_preprocessor { |x| x.values.each { |e| e.capitalize! } }
  #   h.yaml_postprocessor { |yaml| yaml.sub(/\A---\s+/, '') }
  #
  #   puts h['a']        # outputs 'alpha'
  #   puts h.keys.first  # outputs 'a' or 'b' depending on Hash order
  #   puts h.to_yaml     # outputs '{a: Alpha, b: Bravo}'

  class Hash < ::Hash

    def initialize(*args)  # :nodoc:
      @yaml_preprocessor = nil
      @yaml_postprocessor = nil
      @yaml_style = nil
      super
    end

    def self.[](*args)  # :nodoc:
      Sycl::Hash.from_hash super
    end

    # Like Sycl::load_file(), a shortcut method to create a Sycl::Hash
    # from loading and parsing YAML from a file.

    def self.load_file(f)
      Sycl::Hash.from_hash YAML::load_file f
    end

    # Create a Sycl::Array from a normal Hash or Hash-like object. Every
    # child Array or Hash gets promoted to a Sycl::Array or Sycl::Hash.

    def self.from_hash(h)
      retval = Sycl::Hash.new
      h.each { |k, v| retval[k] = Sycl::from_object(v) }
      retval
    end


    # Make sure that if we write to this hash, we promote any inputs
    # to their Sycl equivalents. This lets dot notation, styled YAML,
    # and other Sycl goodies continue.

    def []=(k, v)  # :nodoc:
      unless v.is_a?(Sycl::Hash) || v.is_a?(Sycl::Array)
        v = Sycl::from_object(v)
      end
      super
    end

    def store(k, v)  # :nodoc:
      unless v.is_a?(Sycl::Hash) || v.is_a?(Sycl::Array)
        v = Sycl::from_object(v)
      end
      super
    end

    def merge!(h)  # :nodoc:
      h = Sycl::Hash.from_hash(h) unless h.is_a?(Sycl::Hash)
      super
    end

    def update(h)  # :nodoc:
      h = Sycl::Hash.from_hash(h) unless h.is_a?(Sycl::Hash)
      super
    end


    # Allow method call syntax: h.foo.bar.baz == h['foo']['bar']['baz'].
    #
    # Accessing hash keys whose names overlap with names of Ruby Object
    # built-in methods (id, type, etc.) will still need to be passed in
    # with bracket notation (h['type'] instead of h.type).

    def method_missing(method_symbol, *args, &block)
      key = method_symbol.to_s
      set = key.chomp!('=')
      if set
        self[key] = args.first
      elsif self.key?(key)
        self[key]
      else
        nil
      end
    end


    # Safe dotted notation reads: h.get('foo.bar') == h['foo']['bar'].
    #
    # This will return nil instead of dying if h['foo'] does not exist.

    def get(path)
      path = path.split(/\./) if path.is_a?(String)
      candidate = self
      while !path.empty?
        key = path.shift
        if candidate[key]
          candidate = candidate[key]
        else
          candidate = nil
          last
        end
      end
      candidate
    end


    # Dotted writes: h.set('foo.bar' => 'baz') means h['foo']['bar'] = 'baz'.
    #
    # This will auto-vivify any missing intervening hash keys, and also
    # promote Hash and Array objects in the input to Scyl variants.

    def set(path, value)
      path = path.split(/\./) if path.is_a?(String)
      target = self
      while path.size > 1
        key = path.shift
        if !(target.key?(key) && target[key].is_a?(::Hash))
          target[key] = Sycl::Hash.new
        else
          target[key] = Sycl::Hash.from_hash(target[key])
        end
        target = target[key]
      end
      target[path.first] = value
    end


    # Deep merge two hashes (the new hash wins on conflicts). Hash or
    # and Array objects in the new hash are promoted to Sycl variants.

    def deep_merge(h)
      self.merge(h) do |key, v1, v2|
        if v1.is_a?(::Hash) && v2.is_a?(Sycl::Hash)
          self[key].deep_merge(v2)
        elsif v1.is_a?(::Hash) && v2.is_a?(::Hash)
          self[key].deep_merge(Sycl::Hash.from_hash(v2))
        else
          self[key] = Sycl::from_object(v2)
        end
      end
    end


    # Make Sycl::Hashes sortable alongside Sycl::Hashes and Strings.
    # This makes YAML output in sorted order work.

    include Comparable

    def <=>(other)  # :nodoc:
      self_keys = self.keys.sort
      other_keys = other.respond_to?(:keys) ?  other.keys.sort :
                   other.respond_to?(:sort) ?  other.sort      :
                   other.respond_to?(:to_s) ? [other.to_s]     :
                   other                    ? [other]          : []

      while true
        if self_keys.empty? && other_keys.empty?
          return 0
        elsif self_keys.empty?
          return 1
        elsif other_keys.empty?
          return -1
        else
          self_key = self_keys.shift
          other_key = other_keys.shift
          if self_key != other_key
            return self_key <=> other_key
          end
        end
      end
    end

    # Make this hash, and its children, rendered in inline/flow style.
    # The default is to render arrays in block (multi-line) style.

    def render_inline!
      @yaml_style = :inline
    end

    # Keep rendering this hash in block (multi-line) style, but, make
    # this array's children rendered in inline/flow style.
    #
    # Example:
    #
    #   h = Sycl::Hash.new
    #   h['one'] = 'two'
    #   h['three'] = %w{four five}
    #   h.yaml_postprocessor { |yaml| yaml.sub(/\A---\s+/, '') }
    #
    #   h.render_values_inline!
    #   puts h.to_yaml  # output: "one: two\nthree: [five four]"
    #   h.render_inline!
    #   puts h.to_yaml  # output: '{one: two, three: [five four]}'

    def render_values_inline!
      self.values.each do |v|
        v.render_inline! if v.respond_to?(:render_inline!)
      end
    end


    # Set a preprocessor hook which runs before each time YAML is
    # dumped, for example, via to_yaml() or Sycl::dump(). The hook is a
    # block that gets the object itself as an argument. The hook can
    # then set render_inline!() or similar style arguments, prune nil or
    # empty leaf values from hashes, or do whatever other styling needs
    # to be done before a Sycl object is rendered as YAML.

    def yaml_preprocessor(&block)
      @yaml_preprocessor = block if block_given?
    end

    # Set a postprocessor hook which runs after YML is dumped, for
    # example, via to_yaml() or Sycl::dump(). The hook is a block that
    # gets the YAML text string as an argument, and returns a new,
    # possibly different, YAML text string.
    #
    # A common example use case is to suppress the initial document
    # separator, which is just visual noise when humans are viewing or
    # editing a single YAML file:
    #
    #   a.yaml_postprocessor { |yaml| yaml.sub(/\A---\s+/, '') }
    #
    # Your conventions might also prohibit trailing whitespace, which at
    # least the Syck library will tack on the end of YAML hash keys:
    #
    #   a.yaml_postprocessor { |yaml| yaml.gsub(/:\s+$/, '') }

    def yaml_postprocessor(&block)
      @yaml_postprocessor = block if block_given?
    end

    def yaml_preprocess!  # :nodoc:
      @yaml_preprocessor.call(self) if @yaml_preprocessor
    end

    def yaml_postprocess(yaml)  # :nodoc:
      @yaml_postprocessor ? @yaml_postprocessor.call(yaml) : yaml
    end


    # The Psych YAML engine has a bug that results in infinite recursion
    # if to_yaml is over-ridden on a non-native type.  So, we fake out
    # Psych and pretend Sycl::Hash is a native type.

    class MockNativeType  # :nodoc:
      def source_location
        ['psych/core_ext.rb']
      end
    end

    def method(sym)  # :nodoc:
      sym == :to_yaml ? MockNativeType.new : super
    end


    # Render this object as YAML. Before rendering, run the object
    # through any yaml_preprocessor() code block. After rendering,
    # filter the YAML text through any yaml_postprocessor() code block.
    #
    # Nodes marked with render_inline!() or render_values_inline!()
    # will be output in flow/inline style, all hashes and arrays will
    # be sorted, and we set a long line width to more or less support
    # line wrap under the Psych library.

    def to_yaml(opts = {})
      yaml_preprocess!
      if defined?(YAML::ENGINE) && YAML::ENGINE.yamler == 'psych'
        opts ||= {}
        opts[:line_width] ||= 999999  # Psych doesn't let you disable line wrap
        yaml = super
      else
        yaml = YAML::quick_emit(self, opts) do |out|
          out.map(nil, @yaml_style || to_yaml_style) do |map|
            sort.each { |k, v| map.add(k, v) }
          end
        end
      end
      yaml_postprocess yaml
    end

    if defined?(YAML::ENGINE) && YAML::ENGINE.yamler == 'psych'
      def encode_with(coder)  # :nodoc:
        coder.style = Psych::Nodes::Mapping::FLOW if @yaml_style == :inline
        coder.represent_map nil, sort
      end
    end

  end
end

class String
  alias_method :original_comparator, :<=>

  def <=>(other)
    if other.is_a?(Sycl::Hash)
      -1 * (other <=> self)
    else
      self.__send__(:original_comparator, other)
    end
  end
end
