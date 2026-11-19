require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-6-luna'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def with_api_key(api_key, api_base: nil)
      with_credentials(provider: 'openai', api_key: api_key, api_base: api_base)
    end

    def with_credentials(provider:, api_key: nil, api_base: nil)
      initialize!
      context = RubyLLM.context do |config|
        apply_credentials(config, provider: provider, api_key: api_key, api_base: api_base)
      end

      yield context
    end

    def credentials_for(provider)
      {
        api_key: provider_api_key(provider),
        api_base: provider_api_base(provider)
      }
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        configure_provider(config, 'openai')
        configure_provider(config, 'anthropic')
        configure_provider(config, 'gemini')
        config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
        config.openai_protocol = :chat_completions
        config.logger = Rails.logger
      end
    end

    def configure_provider(config, provider)
      apply_credentials(config, provider: provider, api_key: provider_api_key(provider), api_base: provider_api_base(provider))
    end

    def apply_credentials(config, provider:, api_key:, api_base:)
      case provider.to_s
      when 'anthropic'
        set_optional_key(config, :anthropic_api_key, api_key)
        set_optional_base(config, :anthropic_api_base, api_base)
      when 'gemini', 'google'
        set_optional_key(config, :gemini_api_key, api_key)
        set_optional_base(config, :gemini_api_base, api_base)
      else
        # OpenAI and OpenAI-compatible providers
        config.openai_api_key = api_key if api_key.present?
        config.openai_api_base = normalize_openai_api_base(api_base) if api_base.present?
      end
    end

    def set_optional_key(config, setter, api_key)
      return if api_key.blank?

      method = "#{setter}="
      config.public_send(method, api_key) if config.respond_to?(method)
    end

    def set_optional_base(config, setter, api_base)
      return if api_base.blank?

      method = "#{setter}="
      config.public_send(method, api_base) if config.respond_to?(method)
    end

    def provider_api_key(provider)
      case provider.to_s
      when 'anthropic'
        InstallationConfig.find_by(name: 'CAPTAIN_ANTHROPIC_API_KEY')&.value.presence
      when 'gemini', 'google'
        InstallationConfig.find_by(name: 'CAPTAIN_GEMINI_API_KEY')&.value.presence
      else
        InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value.presence
      end
    end

    def provider_api_base(provider)
      case provider.to_s
      when 'anthropic'
        InstallationConfig.find_by(name: 'CAPTAIN_ANTHROPIC_ENDPOINT')&.value.presence
      when 'gemini', 'google'
        InstallationConfig.find_by(name: 'CAPTAIN_GEMINI_ENDPOINT')&.value.presence
      else
        InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence
      end
    end

    def normalize_openai_api_base(endpoint)
      base = endpoint.to_s.chomp('/')
      return base if base.end_with?('/v1')

      "#{base}/v1"
    end
  end
end
