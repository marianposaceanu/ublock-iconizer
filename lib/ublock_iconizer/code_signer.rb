# frozen_string_literal: true

require 'json'
require 'tmpdir'

module UblockIconizer
  # Re-signs bundles with an identity from the user's keychain, or ad-hoc.
  class CodeSigner
    AD_HOC_IDENTITY = '-'
    # Entitlements that only validate with the original team's provisioning,
    # which a re-signed build cannot carry.
    TEAM_BOUND_ENTITLEMENTS = %w[
      com.apple.application-identifier
      com.apple.developer.team-identifier
      keychain-access-groups
      com.apple.security.application-groups
    ].freeze

    class << self
      def verifies?(bundle)
        Shell.succeeds?('codesign', '--verify', '--deep', '--strict', bundle)
      end

      def default_identity
        identities = Shell.run!('security', 'find-identity', '-v', '-p', 'codesigning')
        identities[/"(Apple Development: [^"]+)"/, 1]
      end
    end

    attr_reader :identity

    def initialize(identity)
      @identity = identity
    end

    def ad_hoc?
      identity == AD_HOC_IDENTITY
    end

    def description
      ad_hoc? ? 'ad-hoc identity' : identity
    end

    def sign!(target, entitlements)
      portable_entitlements = entitlements.reject { |key, _| TEAM_BOUND_ENTITLEMENTS.include?(key) }

      Dir.mktmpdir('ublock-iconizer') do |dir|
        plist = File.join(dir, 'entitlements.plist')
        File.write(plist, entitlements_xml(portable_entitlements))
        Shell.run!(
          'codesign', '--force',
          '--options', 'runtime',
          '--timestamp=none',
          '--entitlements', plist,
          '--sign', identity,
          target
        )
      end
    end

    private

      def entitlements_xml(entitlements)
        Shell.run!('plutil', '-convert', 'xml1', '-o', '-', '-', stdin: JSON.generate(entitlements))
      end
  end
end
