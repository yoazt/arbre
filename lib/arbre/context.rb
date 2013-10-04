require 'arbre/element'
require 'active_support/core_ext/hash/keys'

module Arbre

  # Root of any Arbre construct. Each elements in any Arbre construct will have a reference
  # to this context, which provides information like what the current arbre element is.
  class Context < Container

    ######
    # Initialization

      # Initialize a new Arbre::Context. Any passed block will be instance-exec'd.
      #
      # @param [Hash] assigns
      #   A hash of objects which will be made available as instance variables in the context,
      #   and in some Arbre elements.
      #
      # @param [Object] helpers
      #   An object that has methods on it which will become instance methods within the context.
      #   In a Rails set up, this is typically the +ActionView::Base+ instance used to render the
      #   view.
      def initialize(assigns = nil, helpers = nil, &block)
        @_assigns = (assigns || {}).symbolize_keys
        @_helpers = helpers
        @_element_stack = [ self ]
        @_flow_stack = [ :append ]

        # Pass ourselves as the arbre context to the element.
        super self

        instance_exec &block if block_given?
      end

    ######
    # Attributes

      def assigns
        @_assigns
      end

      def helpers
        @_helpers
      end

      def parent=(*)
        raise NotImplementedError, "Arbre::Context cannot have a parent"
      end

      def indent_level
        -1
      end

    ######
    # Element & flow stack

      def current_element
        @_element_stack.last
      end

      def current_flow
        @_flow_stack.last
      end

      def within_element(element)
        raise ArgumentError, "block required" unless block_given?
        raise ArgumentError, "can't be in the context of nil" unless element

        @_element_stack.push element
        yield
      ensure
        @_element_stack.pop
      end

      # Executes a given block with the specified flow. You typically do not need to call this,
      # but instead you want to use any of the flow methods in {BuildMethods}.
      def with_flow(flow)
        raise ArgumentError, "block required" unless block_given?

        @_flow_stack.push flow
        yield
      ensure
        @_flow_stack.pop
      end

      # Replaces the current flow. For internal usie!
      def replace_current_flow(flow)
        @_flow_stack.pop
        @_flow_stack.push flow
      end

    ######
    # String masquerading

      # ActionView expects the output of any template to be a string. These methods
      # are to ensure the context acts as a string.

      def bytesize
        cached_html.bytesize
      end
      alias :length :bytesize

      def respond_to?(method)
        super || (rendered? && cached_html.respond_to?(method))
      end

      def to_s
        super
      ensure
        @_rendered = true
      end

      private

      def method_missing(method, *args, &block)
        if rendered? && cached_html.respond_to?(method)
          cached_html.send method, *args, &block
        else
          super
        end
      end

      def rendered?
        @_rendered
      end

      def cached_html
        @_cached_html ||= to_s
      end

  end
end
