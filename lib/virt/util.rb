require "rexml/document"
require 'erb'
require 'iconv'

module Virt
  module Util
    # return templated xml to be used by libvirt
    def xml
      to_utf8 ERB.new(template, nil, '-').result(binding)
    end

    def to_utf8 myxml
      # convert string to UTF-8
      ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
      valid_xml = ic.iconv(myxml + ' ')[0..-2]
    end

    def to_gb bytes
      bytes.to_i / 1073741824
    end

    def to_mb bytes
      bytes.to_i / 1048576
    end

    private
    # template file that contain our xml template
    def template
      File.read("#{File.dirname(__FILE__)}/../../templates/#{template_path}")
    rescue => e
      warn "failed to read template #{template_path}: #{e}"
    end

   # finds a value from xml
    def document path, attribute=nil, multi=false, inxml=@xml_desc
      return nil if new?
      xml = REXML::Document.new(inxml)
      if attribute.nil? and !multi
          xml.elements[path].text
      elsif attribute and !multi
          xml.elements[path].attributes[attribute]
      elsif multi
          xml.get_elements(path)
      else
          nil
      end

    end
  end
end
