# -*- coding: utf-8 -*-
$field_alias = {}

module Sablon
  module Statement
    class Insertion < Struct.new(:expr, :field)
      def evaluate(context)
        begin
          $active_fields << expr.name
        rescue
        end
        if content = expr.evaluate(context)
          field.replace(Sablon::Content.wrap(expr.evaluate(context)))
        else
          field.remove
        end
      end
    end

    class Loop < Struct.new(:list_expr, :iterator_name, :block)
      def evaluate(context)
        value = list_expr.evaluate(context)
        value = value.to_ary if value.respond_to?(:to_ary)
        raise ContextError, "The expression #{list_expr.inspect} should evaluate to an enumerable but was: #{value.inspect}" unless value.is_a?(Enumerable)

        old_alias = $field_alias[iterator_name]
        $field_alias[iterator_name] = ""
        if list_expr.respond_to? "name"
          $field_alias[iterator_name] = list_expr.name
        elsif list_expr.respond_to? "expression"
          $field_alias[iterator_name] = list_expr.expression
        end

        begin
          content = value.flat_map do |item|
            iteration_context = context.merge(iterator_name => item)
            block.process(iteration_context)
          end
          block.replace(content.reverse)
        ensure
          $field_alias[iterator_name] = old_alias
        end

      end
    end

    class Condition < Struct.new(:conditon_expr, :block, :predicate)
      def evaluate(context)
        value = conditon_expr.evaluate(context)
        if truthy?(predicate ? value.public_send(predicate) : value)
          block.replace(block.process(context).reverse)
        else
          block.replace([])
        end
      end

      def truthy?(value)
        case value
        when Array;
          !value.empty?
        else
          !!value
        end
      end
    end

    class Comment < Struct.new(:block)
      def evaluate(context)
        block.replace []
      end
    end
  end

  module Expression
    class Variable < Struct.new(:name)
      def evaluate(context)
        context[name]
      end

      def inspect
        "«#{name}»"
      end
    end

    class LookupOrMethodCall < Struct.new(:receiver_expr, :expression)
      def evaluate(context)
        if receiver = receiver_expr.evaluate(context)
          $active_fields << "#{$field_alias[receiver_expr.name] or receiver_expr.name}.#{expression}"
          expression.split(".").inject(receiver) do |local, m|
            case local
            when Hash
              local[m]
            else
              local.public_send m if local.respond_to?(m)
            end
          end
        end
      end

      def inspect
        "«#{receiver_expr.name}.#{expression}»"
      end
    end

    def self.parse(expression)
      if expression.include?(".")
        parts = expression.split(".")
        LookupOrMethodCall.new(Variable.new(parts.shift), parts.join("."))
      else
        Variable.new(expression)
      end
    end
  end
end
