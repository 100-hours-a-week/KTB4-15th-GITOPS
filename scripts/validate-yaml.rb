#!/usr/bin/env ruby

require "psych"

files = Dir.glob("**/*.{yaml,yml}", File::FNM_DOTMATCH).reject do |file|
  file.start_with?(".git/") || file.match?(%r{\A(charts/[^/]+|platform/.+)/templates/})
end.sort

abort "검사할 YAML 파일이 없습니다." if files.empty?

def inspect_node(node, file)
  case node
  when Psych::Nodes::Mapping
    keys = {}
    node.children.each_slice(2) do |key_node, value_node|
      if key_node.is_a?(Psych::Nodes::Scalar)
        key = key_node.value
        if keys.key?(key)
          abort "#{file}: 중복된 YAML 키 '#{key}'가 있습니다."
        end
        keys[key] = true
      end
      inspect_node(value_node, file)
    end
  when Psych::Nodes::Sequence, Psych::Nodes::Document, Psych::Nodes::Stream
    node.children.each { |child| inspect_node(child, file) }
  end
end

files.each do |file|
  begin
    stream = Psych.parse_stream(File.read(file))
    inspect_node(stream, file)
  rescue Psych::SyntaxError => error
    abort "#{file}: YAML 문법 오류: #{error.message}"
  end
end

puts "YAML 문법 및 중복 키 검사 완료: #{files.length}개"
