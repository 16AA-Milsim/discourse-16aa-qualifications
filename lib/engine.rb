# frozen_string_literal: true

require_relative "discourse_16aa_qualifications"

module ::Discourse16aaQualifications
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Discourse16aaQualifications
    config.autoload_paths << File.join(root, "lib")
  end
end
