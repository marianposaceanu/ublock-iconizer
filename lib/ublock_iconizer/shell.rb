# frozen_string_literal: true

require 'open3'

module UblockIconizer
  # Runs external commands and turns a failing exit into an Error.
  module Shell
    module_function

    def run(*command, stdin: nil)
      Open3.capture3(*command, stdin_data: stdin)
    end

    def run!(*command, stdin: nil)
      stdout, stderr, status = run(*command, stdin: stdin)
      return stdout if status.success?

      detail = stderr.strip.empty? ? stdout.strip : stderr.strip
      raise Error, "#{command.first} failed: #{detail}"
    end

    def succeeds?(*command)
      _, _, status = run(*command)
      status.success?
    end

    def which(name)
      stdout, _, status = run('which', name)
      status.success? ? stdout.strip : nil
    end
  end
end
