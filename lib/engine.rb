# frozen_string_literal: true

module ::Discourse16aaQualifications
  PLUGIN_NAME = "discourse-16aa-qualifications"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Discourse16aaQualifications
    config.autoload_paths << File.join(root, "lib")
  end
end

require_relative "discourse_16aa_qualifications"

Discourse16aaQualifications::Engine.routes.draw do
  get "/admin/config" => "admin/config#show"
  put "/admin/config" => "admin/config#update"
  post "/admin/config/reset" => "admin/config#reset"
end
