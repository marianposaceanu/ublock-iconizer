# frozen_string_literal: true

require 'fileutils'
require 'json'

module UblockIconizer
  # Remembers the last patch and restore in state.json.
  class State
    def initialize(dir)
      @file = File.join(dir, 'state.json')
    end

    def read
      return {} unless File.exist?(@file)

      JSON.parse(File.read(@file))
    end

    def write(values)
      FileUtils.mkdir_p(File.dirname(@file))
      File.write(@file, JSON.pretty_generate(values) + "\n")
    end
  end
end
