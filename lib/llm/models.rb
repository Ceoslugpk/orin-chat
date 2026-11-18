module Llm::Models
  CONFIG = YAML.load_file(Rails.root.join('config/llm.yml')).freeze

  class << self
    def providers = CONFIG.fetch('providers')
    def models = CONFIG.fetch('models')
    def features = CONFIG.fetch('features')
    def feature_keys = features.reject { |_key, config| config['internal'] }.keys
    def internal_feature_keys = features.select { |_key, config| config['internal'] }.keys
    def model_feature_keys = features.keys

    def internal_feature?(feature)
      features.dig(feature.to_s, 'internal') == true
    end

    def feature?(feature)
      features.key?(feature.to_s)
    end

    def default_model_for(feature)
      features.dig(feature.to_s, 'default')
    end

    def models_for(feature)
      features.dig(feature.to_s, 'models') || []
    end

    def valid_model_for?(feature, model_name)
      name = model_name.to_s
      return true if models_for(feature).include?(name)

      custom_model_allowed_for?(feature, name)
    end

    def model_config(model_name)
      models[model_name.to_s]
    end

    def registered_model?(model_name)
      RubyLLM.models.find(model_name.to_s).present?
    rescue StandardError
      false
    end

    def provider_for(model_name)
      name = model_name.to_s
      model_config(name)&.dig('provider') || infer_provider_for(name)
    end

    # config/llm.yml can override the registry, which `rake ruby_llm:refresh_models` regenerates.
    def temperature_for(model_name, temperature)
      supported = model_config(model_name)&.dig('temperature')
      if supported.nil?
        supported = begin
          RubyLLM.models.find(model_name).metadata[:temperature]
        rescue StandardError
          nil
        end
      end
      temperature unless supported == false
    end

    def feature_config(feature_key)
      feature = features[feature_key.to_s]
      return nil unless feature

      {
        models: catalog_models_for(feature_key),
        default: feature['default']
      }
    end

    def catalog_models_for(feature_key)
      models_for(feature_key).map do |model_name|
        model = model_config(model_name) || {}
        {
          id: model_name,
          display_name: model['display_name'] || model_name,
          provider: model['provider'] || infer_provider_for(model_name),
          coming_soon: model['coming_soon'],
          credit_multiplier: model['credit_multiplier']
        }
      end
    end

    private

    def custom_model_allowed_for?(feature, model_name)
      return false if model_name.blank?
      return false unless feature?(feature)

      provider = infer_provider_for(model_name)
      return false if provider.blank?

      configured_for_provider?(provider)
    end

    def infer_provider_for(model_name)
      name = model_name.to_s.downcase
      return 'anthropic' if name.start_with?('claude')
      return 'gemini' if name.start_with?('gemini')

      'openai'
    end

    def configured_for_provider?(provider)
      credentials = Llm::Config.credentials_for(provider)
      return credentials[:api_key].present? || credentials[:api_base].present? if provider == 'openai'

      credentials[:api_key].present?
    end
  end
end
