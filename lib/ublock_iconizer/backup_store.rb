# frozen_string_literal: true

require 'fileutils'

module UblockIconizer
  # Keeps one pristine copy of the app per version.
  class BackupStore
    def initialize(root)
      @root = root
    end

    def dir_for(version)
      File.join(@root, 'backup', version)
    end

    def path_for(version, app_name)
      File.join(dir_for(version), app_name)
    end

    def save!(app)
      destination = path_for(app.version, app.name)
      if File.directory?(destination)
        # A backup that still verifies may be the only pristine copy left.
        return destination if CodeSigner.verifies?(destination)

        FileUtils.rm_rf(destination)
      end

      FileUtils.mkdir_p(File.dirname(destination))
      # ditto preserves resource forks, xattrs (App Store metadata) and signatures.
      Shell.run!('ditto', app.path, destination)
      destination
    end

    def restore!(version, app)
      source = path_for(version, app.name)
      raise Error, "No backup for version #{version} at #{source}" unless File.directory?(source)

      unless CodeSigner.verifies?(source)
        raise Error, "Backup at #{source} does not verify; reinstall from the App Store instead"
      end

      guard_removal!(app.path)
      # Copy next to the live app first, then swap, so a failed copy leaves the app in place.
      staging = "#{app.path}.ublock-iconizer-restore"
      FileUtils.rm_rf(staging)
      Shell.run!('ditto', source, staging)
      FileUtils.rm_rf(app.path)
      File.rename(staging, app.path)
    end

    private

      def guard_removal!(path)
        looks_like_app = path.end_with?('.app') && File.directory?(File.join(path, 'Contents/PlugIns'))
        raise Error, "Refusing to remove #{path}: not an app bundle with plug-ins" unless looks_like_app
      end
  end
end
