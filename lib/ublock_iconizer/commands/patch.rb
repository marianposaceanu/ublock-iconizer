# frozen_string_literal: true

require 'time'

module UblockIconizer
  module Commands
    # Backs up the pristine app, recolours the toolbar icons and re-signs.
    class Patch < Base
      def run
        ensure_app_exists!
        take_ownership!
        version = app.version
        signer = CodeSigner.new(resolve_identity)

        case readiness
        when :pristine
          puts "Backing up pristine #{version} build..."
          puts "  -> #{backups.save!(app)}"
        when :already_patched
          puts "Already patched (version #{version}). Nothing to do."
          return
        when :invalid_signature
          raise Error, 'App is modified but not validly signed (a previous patch probably failed mid-way). ' \
                       'Run `ublock-iconizer restore`, or reinstall from the App Store, then patch again.'
        when :foreign_signer
          raise Error, 'App is signed by someone else and not patched by this tool. Reinstall it from the App Store first.'
        end

        recolour_icons(style)
        re_sign(signer)
        app.register
        remember_patch(version, signer)
        print_next_steps
      end

      private

        def style
          STYLES.fetch(options[:style])
        end

        def resolve_identity
          identity = options[:identity] || CodeSigner.default_identity
          return identity if identity

          warn 'warning: no "Apple Development" identity found; signing ad-hoc. Safari will only load the'
          warn '         extension with Develop > Allow Unsigned Extensions, which resets on every launch.'
          CodeSigner::AD_HOC_IDENTITY
        end

        def readiness
          return :pristine if app.pristine?
          return :invalid_signature unless app.signature_valid?
          return :already_patched if icons_grey?

          :foreign_signer
        end

        def icons_grey?
          painter = IconPainter.new
          app.on_icons.all? { |png| painter.grey?(png) }
        end

        def recolour_icons(style)
          puts "Recolouring toolbar icons (style: #{style.name})..."
          painter = IconPainter.new
          paint_all(painter, app.on_icons, style.on)
          paint_all(painter, app.off_icons, style.off)
        end

        def paint_all(painter, pngs, paint)
          return if paint.nil?

          pngs.each do |png|
            raise Error, "Missing icon #{png}" unless File.file?(png)

            painter.paint(png, paint)
          end
        end

        def re_sign(signer)
          puts "Re-signing with #{signer.description}..."
          signer.sign!(app.extension_path, app.entitlements(app.extension_path))
          signer.sign!(app.path, app.entitlements(app.path))
          app.verify_signature!
          puts 'Signature verified.'
        end

        def remember_patch(version, signer)
          state.write(
            'version' => version,
            'patched_at' => Time.now.iso8601,
            'identity' => signer.identity,
            'style' => style.name,
            'app' => app.path
          )
        end

        def print_next_steps
          puts
          puts 'Done. Quit and reopen Safari, then enable the extension in Safari > Settings > Extensions.'
          puts 'Per-site permissions will need to be granted again (the signing team changed).'
        end
    end
  end
end
