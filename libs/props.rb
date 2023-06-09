require 'json'

module Props
  @@unique_object = Object.new

  class Prop
    attr_reader :name, :required, :list_class, :object_class, :map_class, :filter

    def initialize(name, required = true, list_class: nil, object_class: nil, map_class: nil, prop_name: nil,
                   filter: nil)
      @name = name.to_s
      @required = required
      @list_class = list_class
      @object_class = object_class
      @map_class = map_class
      @prop_name = prop_name
      @filter = filter
    end

    def list?
      !@list_class.nil?
    end

    def object?
      !@object_class.nil?
    end

    def map?
      !@map_class.nil?
    end

    def filtered?
      !filter.nil?
    end

    def prop_name
      @prop_name || @name
    end

    def self.parse(input)
      case input
      when String
        parse_string input
      when Symbol
        parse_string input.to_s
      when Array
        parse_array input
      when Hash
        parse_hash input
      end
    end

    def self.parse_string(input)
      new(*parse_name(input))
    end

    def self.parse_array(input)
      input.insert(1, nil) if input[1].is_a? Class
      raw_name, prop_name, list_class, filter = input
      new(*parse_name(raw_name), list_class:, prop_name:, filter:)
    end

    def self.parse_hash(input)
      input.entries.map do |raw_name, object_class|
        if object_class.instance_of? Array
          new(*parse_name(raw_name), list_class: object_class.first)
        elsif object_class.instance_of? Hash
          _key, map_class = object_class.entries.first
          new(*parse_name(raw_name), map_class:)
        else
          new(*parse_name(raw_name), object_class:)
        end
      end
    end

    def self.parse_name(input)
      if input.end_with? '?'
        [input[..-2], false]
      else
        [input, true]
      end
    end
  end

  module Includes
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def read(filename)
        input = JSON.parse(File.read(filename))
        new input
      end
    end

    def write(filename)
      File.write filename, JSON.pretty_generate(serialize)
    end

    def init(input)
      props.map do |prop|
        prop_name = prop.prop_name
        required = prop.required
        name = prop.name
        key = input.has_key?(name) ? name : name.to_sym
        value = required ? input.fetch(key) : input.fetch(key, nil)
        if prop.list?
          list_class = prop.list_class
          filter = prop.filter
          value = value&.filter(&filter) if filter
          list = value&.map do |input|
            input.is_a?(list_class) ? input : list_class.new(input)
          end
          instance_variable_set "@#{prop_name}", list
        elsif prop.map?
          map_class = prop.map_class
          entries = value&.entries&.map { |k, v| [k, v.is_a?(map_class) ? v : map_class.new(v)] }
          instance_variable_set "@#{prop_name}", entries ? Hash[entries] : nil
        elsif prop.object?
          object_class = prop.object_class
          object = value.is_a?(object_class) ? value : object_class.new(value)
          instance_variable_set "@#{prop_name}", object
        else
          instance_variable_set "@#{prop_name}", value
        end
      end
    end

    def serialize
      entries = props.map do |prop|
        name = prop.name
        prop_name = prop.prop_name
        raw_value = instance_variable_get "@#{prop_name}"
        if raw_value.nil?
          nil
        elsif prop.list?
          prop.filtered? ? nil : [name, raw_value&.map(&:serialize)]
        elsif prop.object?
          value = raw_value&.serialize
          [name, value]
        elsif prop.map?
          entries = raw_value&.entries&.map { |k, v| [k, v.serialize] }
          [name, entries ? Hash[entries] : nil]
        else
          [name, raw_value]
        end
      end.filter { |entry| !entry.nil? }
      Hash[entries]
    end
  end

  refine Class do
    def props(*args, **named)
      if args.empty? && named.empty?
        @props
      else
        init_props
        props = args.map { |arg| Prop.parse arg }.flatten
        props += Prop.parse named
        props.each do |prop|
          name = prop.prop_name
          if prop.map?
            define_method name do |key = nil, value = @@unique_object|
              map = instance_variable_get("@#{name}")
              if value == @@unique_object
                key && map ? map[key.to_s] : map
              else
                map[key.to_s] = value
              end
            end
          else
            attr_accessor name
          end
        end
        @props += props
      end
    end

    def prop(name, prop_name, required: true, object_class: nil)
      init_props
      prop = Prop.new(name, required, prop_name:, object_class:)
      attr_accessor prop.prop_name

      @props << prop
    end

    def list(name, list_class, prop_name = nil, required: true, &filter)
      init_props
      prop = Prop.new(name, required, prop_name:, list_class:, filter:)
      attr_accessor prop.prop_name

      @props << prop
    end

    private

    def init_props
      return if include?(Includes)

      @props = []
      include Includes
      define_initialize
      define_props
    end

    def define_props
      define_method :props do
        ancestor_props = self.class.superclass.props
        ancestor_props ? ancestor_props + self.class.props : self.class.props
      end
    end

    def define_initialize
      define_method :initialize do |input = nil, **named|
        if input
          init input
        elsif !named.empty?
          init named
        end
      end
    end
  end
end
