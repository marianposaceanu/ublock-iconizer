# frozen_string_literal: true

require 'optparse'

module UblockIconizer
  # Parses the command line and runs the chosen command.
  class CLI
    COMMANDS = {
      'status' => Commands::Status,
      'patch' => Commands::Patch,
      'restore' => Commands::Restore
    }.freeze
    USAGE = 'usage: ublock-iconizer (status|patch|restore) [--app PATH] [--identity NAME] ' \
            '[--style grey|template] [--delete-backup]'

    def initialize(argv)
      @argv = argv.dup
      @options = { app: DEFAULT_APP_PATH, identity: nil, delete_backup: false, style: 'grey' }
    end

    def run
      command_class = COMMANDS.fetch(parse_command_name) { usage(1) }
      command = command_class.new(
        app: AppBundle.new(@options[:app]),
        backups: BackupStore.new(SUPPORT_DIR),
        state: State.new(SUPPORT_DIR),
        options: @options
      )
      command.run
      0
    rescue Error => e
      warn "error: #{e.message}"
      1
    end

    private

      def parse_command_name
        parser = OptionParser.new do |o|
          o.banner = 'usage: ublock-iconizer (status|patch|restore) [options]'
          o.on('--app PATH', "App bundle to operate on (default: #{DEFAULT_APP_PATH})") do |value|
            @options[:app] = File.expand_path(value)
          end
          o.on('--identity NAME', 'codesign identity (default: first "Apple Development" identity, else ad-hoc)') do |value|
            @options[:identity] = value
          end
          o.on('--delete-backup', 'restore: remove the pristine backup afterwards') do
            @options[:delete_backup] = true
          end
          o.on('--style STYLE', STYLES.keys, "patch: #{STYLES.keys.join('|')} (default: grey). " \
                                             'template is tinted blue by Safari on tabs the extension can access') do |value|
            @options[:style] = value
          end
          o.on('-h', '--help') do
            puts o
            exit 0
          end
        end
        parser.parse!(@argv)
        @argv.shift || usage(1)
      end

      def usage(code)
        warn USAGE
        exit code
      end
  end
end
