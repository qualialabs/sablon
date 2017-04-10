require 'singleton'
require 'zip'
require 'nokogiri'
require 'json'

require_relative "sablon/version"
require_relative "sablon/numbering"
require_relative "sablon/context"
require_relative "sablon/template"
require_relative "sablon/processor/document"
require_relative "sablon/processor/section_properties"
require_relative "sablon/processor/numbering"
require_relative "sablon/parser/mail_merge"
require_relative "sablon/operations"
require_relative "sablon/html/converter"
require_relative "sablon/content"

require 'redcarpet'

module Sablon
  class TemplateError < ArgumentError; end
  class ContextError < ArgumentError; end

  def self.template(path)
    Template.new(path)
  end

  def self.content(type, *args)
    Content.make(type, *args)
  end
end

doc = Sablon.template(ARGV[0])

json = File.open(ARGV[2], "rb")
data = JSON.parse(json.read)
json.close

puts doc.render_to_file(ARGV[1], data).to_json
