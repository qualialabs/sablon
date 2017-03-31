module Sablon
  module Parser
    class MailMerge
      class MergeField
        KEY_PATTERN = /\s*MERGEFIELD\s+([^ ]+)\s+\\\*\s+MERGEFORMAT\s*/

        def valid?
          expression
        end

        def expression
          $1 if @raw_expression =~ KEY_PATTERN
        end

        private
        def replace_field_display(node, content)
          paragraph = node.ancestors(".//w:p").first
          display_node = get_display_node(node)
          content.append_to(paragraph, display_node)
          display_node.remove
        end

        def get_display_node(node)
          node.search(".//w:t").first
        end
      end

      class ComplexField < MergeField
        def initialize(nodes)
          @nodes = nodes
          @raw_expression = @nodes.flat_map {|n| n.search(".//w:instrText").map(&:content) }.join
        end

        def valid?
          separate_node && get_display_node(pattern_node) && expression
        end

        def replace(content)
          # Having more than 5 nodes means that it's a hyperlinked node
          # We delete the first three nodes, which contain the start, link and separator, and the last node, which is the end
          if @nodes.length > 5
            replace_field_display(pattern_node, content)
            @nodes.each_with_index do |node, index|
              if index < 3 || index == 8
                node.remove
              end
            end
          else
            replace_field_display(pattern_node, content)
            (@nodes - [pattern_node]).each(&:remove)
          end
        end

        def remove
          @nodes.each(&:remove)
        end

        def ancestors(*args)
          @nodes.first.ancestors(*args)
        end

        def start_node
          @nodes.first
        end

        def end_node
          @nodes.last
        end

        private
        def pattern_node
          # If the next element doesn't a fldChar, it's a hyperlink, and we need to traverse past the begin, hyperlink, and seprator to get to the pattern node
          if separate_node.next_element.search('.//w:fldChar').length != 0
            separate_node.next_element.next_element.next_element.next_element
          else
            separate_node.next_element
          end
        end

        def separate_node
          @nodes.detect {|n| !n.search(".//w:fldChar[@w:fldCharType='separate']").empty? }
        end
      end

      class SimpleField < MergeField
        def initialize(node)
          @node = node
          @raw_expression = @node["w:instr"]
        end

        def replace(content)
          replace_field_display(@node, content)
          @node.replace(@node.children)
        end

        def remove
          @node.remove
        end

        def ancestors(*args)
          @node.ancestors(*args)
        end

        def start_node
          @node
        end
        alias_method :end_node, :start_node
      end

      def parse_fields(xml)
        fields = []
        xml.traverse do |node|
          if node.name == "fldSimple"
            field = SimpleField.new(node)
          elsif node.name == "fldChar" && node["w:fldCharType"] == "begin"
            field = build_complex_field(node)
          end
          fields << field if field && field.valid?
        end
        fields
      end

      private
      def build_complex_field(node)
        begins_left = 0
        possible_field_node = node.parent
        field_nodes = [possible_field_node]
        while possible_field_node && (possible_field_node.search(".//w:fldChar[@w:fldCharType='end']").empty? || begins_left > 1)
          if !possible_field_node.search(".//w:fldChar[@w:fldCharType='begin']").empty?
            begins_left += 1
          elsif !possible_field_node.search(".//w:fldChar[@w:fldCharType='end']").empty?
            begins_left -= 1
          end
          possible_field_node = possible_field_node.next_element
          field_nodes << possible_field_node
        end
        ComplexField.new(field_nodes)
      end
    end
  end
end
