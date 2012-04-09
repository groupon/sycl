# sycl.rb - Simple YAML Configuration Library
# Andrew Ho (ho@groupon.com)
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

module Sycl

  # Sycl::load(yaml), Sycl::load_file(filename), and Sycl::dump(object)
  # function just like their YAML counterparts, but return and act on
  # Sycl-blessed variants of Hashes and Arrays.

  def self.load(yaml)
    from_object YAML::load(yaml)
  end

  def self.load_file(filename)
    from_object YAML::load_file(filename)
  end

  def self.dump(object)
    if (object.is_a?(Hash)  && !object.is_a?(SyclHash)) ||
       (object.is_a?(Array) && !object.is_a?(SyclArray))
      sycl_version = from_object object
      sycl_version.to_yaml
    else
      object.to_yaml
    end
  end

  private

  def self.from_object(o)
    if o.is_a?(Hash)
      SyclHash.from_hash(o)
    elsif o.is_a?(Array)
      SyclArray.from_array(o)
    else
      o
    end
  end


  # A SyclArray is like an Array, but creating one from an array blesses
  # any child Array or Hash objects into SyclArray or SyclHash objects.
  #
  # SyclArrays support YAML preprocessing and postprocessing, and having
  # individual nodes marked as being rendered in inline style. YAML
  # output is also always sorted.

  class SyclArray < Array
    def initialize(*args)
      @yaml_preprocessor = nil
      @yaml_postprocessor = nil
      @yaml_style = nil
      super
    end

    def self.load_file(f)
      SyclArray.from_array YAML::load_file f
    end

    def self.from_array(a)
      retval = SyclArray.new
      a.each { |e| retval << Sycl::from_object(e) }
      retval
    end


    # Make sure that if we write to this array, we promote any inputs
    # to their Sycl equivalents. This lets dot notation, styled YAML,
    # and other Sycl goodies continue.

    def []=(*args)
      raise ArgumentError => 'wrong number of arguments' unless args.size > 1
      unless args[-1].is_a?(SyclHash) || args[-1].is_a?(SyclArray)
        args[-1] = Sycl::from_object(args[-1])
      end
      super
    end

    def <<(e)
      e = Sycl::from_object(e) unless e.is_a?(SyclHash) || e.is_a?(SyclArray)
      super
    end

    def collect!(&block)
      super { |o| Sycl::from_object(block.call o) }
    end
    alias_method :map!, :collect!

    def concat(a)
      a = SyclArray.from_array(a) unless a.is_a?(SyclArray)
      super
    end

    def fill(*args, &block)
      raise ArgumentError => 'wrong number of arguments' if args.empty?
      if block_given?
        super { |idx| Sycl::from_object(block.call idx) }
      else
        unless args[0].is_a?(SyclHash) || args[0].is_a?(SyclArray)
          args[0] = Sycl::from_object(args[0])
        end
        super
      end
    end

    def insert(i, *args)
      raise ArgumentError => 'wrong number of arguments' if args.empty?
      args.collect! do |o|
        o = Sycl::from_object(o) unless o.is_a?(SyclHash) || o.is_a?(SyclArray)
      end
      super
    end

    def push(*args)
      raise ArgumentError => 'wrong number of arguments' if args.empty?
      args.collect! do |o|
        o = Sycl::from_object(o) unless o.is_a?(SyclHash) || o.is_a?(SyclArray)
      end
      super
    end

    def replace(a)
      a = SyclArray.from_array(a) unless a.is_a?(SyclArray)
      super
    end

    def unshift(*args)
      raise ArgumentError => 'wrong number of arguments' if args.empty?
      args.collect! do |o|
        o = Sycl::from_object(o) unless o.is_a?(SyclHash) || o.is_a?(SyclArray)
      end
      super
    end


    # Make this array, or its children, rendered in inline/flow style YAML.
    # The default is to render arrays in block (multi-line) style.

    def render_inline!
      @yaml_style = :inline
    end

    def render_values_inline!
      self.each do |e|
        e.render_inline! if e.respond_to?(:render_inline!)
      end
    end


    # Hooks to run before and after YAML dumping

    def yaml_preprocessor(&block)
      @yaml_preprocessor = block if block_given?
    end

    def yaml_postprocessor(&block)
      @yaml_postprocessor = block if block_given?
    end

    def yaml_preprocess!
      @yaml_preprocessor.call(self) if @yaml_preprocessor
    end

    def yaml_postprocess(yaml)
      @yaml_postprocessor ? @yaml_postprocessor.call(yaml) : yaml
    end


    # The Psych YAML engine has a bug that results in infinite recursion
    # if to_yaml is over-ridden on a non-native type.  So, we fake out
    # Psych and pretend SyclArray is a native type.

    class MockNativeType
      def source_location
        ['psych/core_ext.rb']
      end
    end

    def method(sym)
      sym == :to_yaml ? MockNativeType.new : super
    end


    # YAML rendering overrides: run preprocessing and postprocessing,
    # set flow/inline style if this node is marked accordingly, sort
    # elements, and suppress taguri on output. For Psych, set a long line
    # width to more or less suppress line wrap.

    if defined?(YAML::ENGINE) && YAML::ENGINE.yamler == 'psych'
      def encode_with(coder)
        coder.style = Psych::Nodes::Sequence::FLOW if @yaml_style == :inline
        coder.represent_seq nil, sort
      end
    end

    def to_yaml(opts = {})
      yaml_preprocess!
      if defined?(YAML::ENGINE) && YAML::ENGINE.yamler == 'psych'
        opts ||= {}
        opts[:line_width] ||= 999999
        yaml = super
      else
        yaml = YAML::quick_emit(self, opts) do |out|
          out.seq(nil, @yaml_style || to_yaml_style) do |seq|
            sort.each { |e| seq.add(e) }
          end
        end
      end
      yaml_postprocess yaml
    end

  end


  # A SyclHash is like a Hash, but creating one from an hash blesses
  # any child Array or Hash objects into SyclArray or SyclHash objects.
  #
  # Hash contents can be accessed via "dot notation" (h.foo.bar means
  # the same as h['foo']['bar']). However, h.foo.bar dies if h['foo']
  # does not exist, so get() and set() methods exist: h.get('foo.bar')
  # will return nil instead of dying if h['foo'] does not exist.
  # There is also a convenient deep_merge() that is like Hash#merge(),
  # but also descends into and merges child nodes of the new hash.
  #
  # SyclHashes support YAML preprocessing and postprocessing, and having
  # individual nodes marked as being rendered in inline style. YAML
  # output is also always sorted by key.

  class SyclHash < Hash

    def initialize(*args)
      @yaml_preprocessor = nil
      @yaml_postprocessor = nil
      @yaml_style = nil
      super
    end

    def self.load_file(f)
      SyclHash.from_hash YAML::load_file f
    end

    def self.from_hash(h)
      retval = SyclHash.new
      h.each { |k, v| retval[k] = Sycl::from_object(v) }
      retval
    end


    # Make sure that if we write to this hash, we promote any inputs
    # to their Sycl equivalents. This lets dot notation, styled YAML,
    # and other Sycl goodies continue.

    def []=(k, v)
      v = Sycl::from_object(v) unless v.is_a?(SyclHash) || v.is_a?(SyclArray)
      super
    end
    alias_method :store, :[]=

    def merge!(h)
      h = SyclHash.from_hash(h) unless h.is_a?(SyclHash)
      super
    end
    alias_method :update, :merge!


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
        if !(target.key?(key) && target[key].is_a?(Hash))
          target[key] = SyclHash.new
        else
          target[key] = SyclHash.from_hash(target[key])
        end
        target = target[key]
      end
      target[path.first] = value
    end


    # Deep merge two hashes (the new hash wins on conflicts). Hash or
    # and Array objects in the new hash are promoted to Sycl variants.

    def deep_merge(h)
      self.merge(h) do |key, v1, v2|
        if v1.is_a?(Hash) && v2.is_a?(SyclHash)
          self[key].deep_merge(v2)
        elsif v1.is_a?(Hash) && v2.is_a?(Hash)
          self[key].deep_merge(SyclHash.from_hash(v2))
        else
          self[key] = Sycl::from_object(v2)
        end
      end
    end


    # Make SyclHashes sortable alongside SyclHashes and Strings.
    # This makes YAML output in sorted order work.

    include Comparable

    def <=>(another)
      self.to_str <=> another.to_str
    end

    def to_str
      self.keys.sort.first
    end


    # Make this hash, or its children, rendered in inline/flow style YAML.
    # The default is to render hashes in block (multi-line) style.

    def render_inline!
      @yaml_style = :inline
    end

    def render_values_inline!
      self.values.each do |v|
        v.render_inline! if v.respond_to?(:render_inline!)
      end
    end


    # Hooks to run before and after YAML dumping

    def yaml_preprocessor(&block)
      @yaml_preprocessor = block if block_given?
    end

    def yaml_postprocessor(&block)
      @yaml_postprocessor = block if block_given?
    end

    def yaml_preprocess!
      @yaml_preprocessor.call(self) if @yaml_preprocessor
    end

    def yaml_postprocess(yaml)
      @yaml_postprocessor ? @yaml_postprocessor.call(yaml) : yaml
    end


    # The Psych YAML engine has a bug that results in infinite recursion
    # if to_yaml is over-ridden on a non-native type.  So, we fake out
    # Psych and pretend SyclArray is a native type.

    class MockNativeType
      def source_location
        ['psych/core_ext.rb']
      end
    end

    def method(sym)
      sym == :to_yaml ? MockNativeType.new : super
    end


    # YAML rendering overrides: run preprocessing and postprocessing,
    # set flow/inline style if this node is marked accordingly, sort by
    # key, and suppress taguri on output. For Psych, set a long line
    # width to more or less suppress line wrap.

    if defined?(YAML::ENGINE) && YAML::ENGINE.yamler == 'psych'
      def encode_with(coder)
        coder.style = Psych::Nodes::Mapping::FLOW if @yaml_style == :inline
        coder.represent_map nil, sort
      end
    end

    def to_yaml(opts = {})
      yaml_preprocess!
      if defined?(YAML::ENGINE) && YAML::ENGINE.yamler == 'psych'
        opts ||= {}
        opts[:line_width] ||= 999999
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

  end
end
