# frozen_string_literal: true

module UblockIconizer
  module Commands
    # Prints version, signer, icon state and backup presence.
    class Status < Base
      def run
        ensure_app_exists!
        version = app.version
        last = state.read

        puts "App:        #{app.path}"
        puts "Version:    #{version}"
        puts "Signed by:  #{signer_line}"
        puts "Icons:      #{icons_line(last)}"
        puts "Backup:     #{backup_line(version)}"
        puts "Last patch: #{last['patched_at'] || 'never'} (version #{last['version'] || '-'})" if last.any?

        return unless updated_since_last_patch?(version, last)

        puts
        puts 'The App Store has updated the app since the last patch. Run `ublock-iconizer patch` again.'
      end

      private

        def signer_line
          authority = app.signing_authority || 'unsigned'
          app.signature_valid? ? authority : "#{authority} (signature INVALID)"
        end

        def icons_line(last)
          painter = IconPainter.new
          return 'coloured (stock)' unless app.on_icons.all? { |png| painter.grey?(png) }

          last['style'] ? "grey (patched, style #{last['style']})" : 'grey (patched)'
        end

        def backup_line(version)
          backup = backups.path_for(version, app.name)
          File.directory?(backup) ? backup : 'none for this version'
        end

        def updated_since_last_patch?(version, last)
          return false unless app.pristine?
          return false if last['version'].nil?

          last['version'] != version
        end
    end
  end
end
