module Props
  class Prop
    attr_reader :name, :required, :list_class, :object_class, :filter

    def initialize(name, required = true, list_class: nil, object_class: nil, prop_name: nil, filter: nil)
      @name = name.to_s
      @required = required
      @list_class = list_class
      @object_class = object_class
      @prop_name = prop_name
      @filter = filter
    end

    def list?
      !@list_class.nil?
    end

    def object?
      !@object_class.nil?
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

    private

    def self.parse_string(input)
      self.new *parse_name(input)
    end

    def self.parse_array(input)
      input.insert(1, nil) if input[1].is_a? Class
      raw_name, prop_name, list_class, filter = input
      self.new *parse_name(raw_name), list_class: list_class, prop_name: prop_name, filter: filter
    end

    def self.parse_hash(input)
      input.entries.map do |raw_name, object_class|
        if object_class.instance_of? Array
          self.new *parse_name(raw_name), list_class: object_class.first
        else
          self.new *parse_name(raw_name), object_class: object_class
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

  refine Class do
    def props(*args, **named)
      unless args.empty? && named.empty?
        init_props
        # Create the new property objects
        props = args.map { |arg| Prop.parse arg }.flatten
        props += Prop.parse named
        # Create accessors
        props.each { |prop| attr_accessor prop.prop_name }
        # Add the new properties to the list of properties
        @props += props
      else
        @props 
      end
    end

    def prop(name, prop_name, required: true, object_class: nil)
      init_props
      prop = Prop.new name, required, prop_name: prop_name, object_class: object_class
      attr_accessor prop.prop_name
      @props << prop
    end

    def list(name, list_class, prop_name = nil, required: true, &filter)
      init_props
      prop = Prop.new name, required, prop_name: prop_name, list_class: list_class, filter: filter
      attr_accessor prop.prop_name
      @props << prop
    end

    private

    def init_props
      if @props.nil? # Only create these methods once
        @props = []
        # Define the init method
        define_init
        # Create a constructor that calls the init method
        define_initialize
        # Create a serialization method
        define_serialize
        # Create a props method
        define_props
      end 
    end

    def define_props
      define_method :props do
        ancestor_props = self.class.superclass.props
        ancestor_props ? ancestor_props + self.class.props : self.class.props
      end
    end

    def define_init
      define_method :init do |input|
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
            instance_variable_set "@#{prop_name}", value&.map do |input|
              input.is_a?(list_class) ? input : list_class.new(input)
            end
          elsif prop.object?
            object_class = prop.object_class
            object = value.is_a?(object_class) ? value : object_class.new(value)
            instance_variable_set "@#{prop_name}", object
          else
            instance_variable_set "@#{prop_name}", value
          end
        end
      end
    end

    def define_initialize
      define_method :initialize do |input, **named|
        if input
          init input
        elsif !named.empty?
          init named
        end
      end
    end

    def define_serialize
      define_method :serialize do
        entries = props.map do |prop|
          name = prop.name
          prop_name = prop.prop_name
          raw_value = instance_variable_get "@#{prop_name}"
          if raw_value.nil?
            nil
          else
            if prop.list?
              prop.filtered? ? nil : [name, raw_value&.map(&:serialize)]
            elsif prop.object?
              value = raw_value&.serialize
              [name, value]
            else
              [name, raw_value]
            end
          end
        end.filter { |entry| !entry.nil? }
        Hash[entries]
      end
    end
  end
end
