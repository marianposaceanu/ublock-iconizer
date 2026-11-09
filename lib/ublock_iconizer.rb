# frozen_string_literal: true

require_relative 'ublock_iconizer/shell'
require_relative 'ublock_iconizer/style'
require_relative 'ublock_iconizer/app_bundle'
require_relative 'ublock_iconizer/icon_painter'
require_relative 'ublock_iconizer/code_signer'
require_relative 'ublock_iconizer/state'
require_relative 'ublock_iconizer/backup_store'
require_relative 'ublock_iconizer/commands/base'
require_relative 'ublock_iconizer/commands/status'
require_relative 'ublock_iconizer/commands/patch'
require_relative 'ublock_iconizer/commands/restore'
require_relative 'ublock_iconizer/cli'

# Makes the uBlock Origin Lite toolbar icon in Safari a grey template icon
# and restores the pristine App Store build on request.
module UblockIconizer
  DEFAULT_APP_PATH = '/Applications/uBlock Origin Lite.app'
  DEFAULT_SUPPORT_DIR = '~/Library/Application Support/ublock-iconizer'
  SUPPORT_DIR = File.expand_path(ENV.fetch('UBLOCK_ICONIZER_HOME', DEFAULT_SUPPORT_DIR))

  class Error < StandardError; end
end
