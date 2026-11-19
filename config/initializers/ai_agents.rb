# frozen_string_literal: true

require 'agents'

Rails.application.config.after_initialize do
  openai_api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
  model = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || LlmConstants::DEFAULT_MODEL
  openai_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value || LlmConstants::OPENAI_API_ENDPOINT
  anthropic_api_key = InstallationConfig.find_by(name: 'CAPTAIN_ANTHROPIC_API_KEY')&.value
  gemini_api_key = InstallationConfig.find_by(name: 'CAPTAIN_GEMINI_API_KEY')&.value

  Agents.configure do |config|
    config.openai_api_key = openai_api_key if openai_api_key.present?
    if openai_endpoint.present?
      api_base = "#{openai_endpoint.chomp('/')}/v1"
      config.openai_api_base = api_base unless api_base == "#{LlmConstants::OPENAI_API_ENDPOINT}/v1" && openai_api_key.blank?
    end
    config.anthropic_api_key = anthropic_api_key if anthropic_api_key.present? && config.respond_to?(:anthropic_api_key=)
    config.gemini_api_key = gemini_api_key if gemini_api_key.present? && config.respond_to?(:gemini_api_key=)
    config.default_model = model
    config.openai_protocol = :chat_completions
    config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
    config.debug = false
  end
rescue StandardError => e
  Rails.logger.error "Failed to configure AI Agents SDK: #{e.message}"
end
