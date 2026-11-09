# frozen_string_literal: true

require 'fileutils'
require 'time'

module UblockIconizer
  module Commands
    # Swaps the verified pristine backup back into place.
    class Restore < Base
      def run
        ensure_app_exists!
        version = app.version
        if app.pristine?
          puts "App is the pristine App Store build (#{version}). Nothing to restore."
          return
        end

        take_ownership!
        puts "Restoring pristine #{version} build from backup..."
        backups.restore!(version, app)
        app.verify_signature!
        app.register
        delete_backup(version) if options[:delete_backup]
        state.write(state.read.merge('restored_at' => Time.now.iso8601))
        puts 'Done. Quit and reopen Safari. The App Store can update the app again.'
      end

      private

        def delete_backup(version)
          FileUtils.rm_rf(backups.dir_for(version))
          puts 'Backup deleted.'
        end
    end
  end
end
