require 'i18n'
require 'dry-validation'

module RailsSettingsUi
  module CustomPredicates
    include Dry::Logic::Predicates

    predicate(:form_hash?) do |value|
      begin
        JSON.parse(value.gsub(/\=\>/, ':'))
        true
      rescue JSON::ParserError
        false
      end
    end
  end

  class SettingsFormContract < Dry::Validation::Contract
    params do
      # dynamically built below
    end

    config.messages.load_paths << 'config/locales/errors.yml'
    config.messages.backend = :i18n
    config.predicates = CustomPredicates
  end

  class SettingsFormValidator
    VALIDATABLE_TYPES = {
      Integer => :int?,
      Float => :float?,
      ActiveSupport::Duration => :int?,
      ActiveSupport::HashWithIndifferentAccess => :form_hash?
    }.freeze

    def initialize(default_settings, settings)
      @default_settings = default_settings
      @settings = settings
      @contract = build_validation_contract
    end

    def errors
      result = @contract.call(@settings.to_hash)
      result.errors.to_h
    end

    private

    def build_validation_contract
      keys = validatable_settings

      Class.new(SettingsFormContract) do
        params do
          keys.each do |name, value|
            predicate = VALIDATABLE_TYPES[value.class]
            required(name.to_sym).filled(predicate) if predicate
          end
        end
      end.new
    end

    def validatable_settings
      @default_settings.select { |_, value| VALIDATABLE_TYPES.key?(value.class) }
    end
  end
end
