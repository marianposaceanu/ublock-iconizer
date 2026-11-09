# frozen_string_literal: true

require 'json'

module UblockIconizer
  # The installed app bundle and the Safari extension inside it.
  class AppBundle
    EXTENSION_RELATIVE_PATH = 'Contents/PlugIns/uBlock Origin Lite Extension.appex'
    APP_STORE_AUTHORITY = 'Apple Mac OS Application Signing'
    ICON_SIZES = [16, 32, 64, 128].freeze
    LSREGISTER = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'

    attr_reader :path

    def initialize(path)
      @path = path
    end

    def name
      File.basename(path)
    end

    def extension_path
      File.join(path, EXTENSION_RELATIVE_PATH)
    end

    def image_dir
      File.join(extension_path, 'Contents/Resources/img')
    end

    def exist?
      File.directory?(path) && File.directory?(extension_path)
    end

    def version
      info_plist = File.join(path, 'Contents/Info.plist')
      Shell.run!('plutil', '-extract', 'CFBundleShortVersionString', 'raw', info_plist).strip
    end

    def on_icons
      ICON_SIZES.map { |size| File.join(image_dir, "icon_#{size}.png") }
    end

    def off_icons
      ICON_SIZES.map { |size| File.join(image_dir, "icon_#{size}_off.png") }
    end

    def signing_authority
      _, stderr, = Shell.run('codesign', '-dv', '--verbose=2', path)
      stderr[/^Authority=(.*)$/, 1]
    end

    def app_store_signed?
      signing_authority == APP_STORE_AUTHORITY
    end

    def signature_valid?
      CodeSigner.verifies?(path)
    end

    # Untouched App Store build: Apple-signed and the seal still verifies.
    def pristine?
      app_store_signed? && signature_valid?
    end

    def verify_signature!
      Shell.run!('codesign', '--verify', '--deep', '--strict', path)
    end

    def entitlements(target = path)
      xml = Shell.run!('codesign', '-d', '--entitlements', '-', '--xml', target)
      return {} if xml.strip.empty?

      json = Shell.run!('plutil', '-convert', 'json', '-o', '-', '-', stdin: xml)
      JSON.parse(json)
    end

    def writable?
      File.writable?(image_dir) && File.writable?(File.dirname(path))
    end

    # Tell LaunchServices and pluginkit about the re-signed bundle so Safari
    # picks up the new one.
    def register
      Shell.run(LSREGISTER, '-f', path)
      Shell.run('pluginkit', '-a', extension_path)
    end
  end
end
