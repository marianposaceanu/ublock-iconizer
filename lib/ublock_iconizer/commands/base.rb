# frozen_string_literal: true

module UblockIconizer
  module Commands
    # Shared collaborators and checks for the three commands.
    class Base
      def initialize(app:, backups:, state:, options:)
        @app = app
        @backups = backups
        @state = state
        @options = options
      end

      private

        attr_reader :app, :backups, :state, :options

        def ensure_app_exists!
          return if app.exist?

          raise Error, "App not found at #{app.path}. Install uBlock Origin Lite from the App Store first."
        end

        # App Store installs are owned by root. Signing must run as the user
        # (the identity lives in the user's keychain), so take ownership once.
        def take_ownership!
          return if app.writable?

          user = Shell.run!('id', '-un').strip
          puts "#{app.path} is not writable by #{user}; taking ownership (sudo will ask for your password)..."
          return if system('sudo', 'chown', '-R', "#{user}:staff", app.path)

          raise Error, "could not take ownership. Run manually: sudo chown -R #{user}:staff #{app.path.inspect}"
        end
    end
  end
end
