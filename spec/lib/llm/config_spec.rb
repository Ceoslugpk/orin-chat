require 'rails_helper'

RSpec.describe Llm::Config do
  before do
    described_class.reset!
  end

  describe '.configure_ruby_llm' do
    it 'adds the API version to the configured OpenAI endpoint' do
      original_base = RubyLLM.config.openai_api_base
      InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT').update!(value: 'https://example.test/')

      described_class.send(:configure_ruby_llm)

      expect(RubyLLM.config.openai_api_base).to eq('https://example.test/v1')
    ensure
      RubyLLM.configure { |config| config.openai_api_base = original_base }
    end
  end

  describe '.credentials_for' do
    it 'returns configured credentials for each provider' do
      InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_OPEN_AI_API_KEY').update!(value: 'openai-key')
      InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT').update!(value: 'https://example.test/')
      InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_ANTHROPIC_API_KEY').update!(value: 'anthropic-key')
      InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_ANTHROPIC_ENDPOINT').update!(value: 'https://anthropic.example/')
      InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_GEMINI_API_KEY').update!(value: 'gemini-key')

      expect(described_class.credentials_for('openai')).to eq(api_key: 'openai-key', api_base: 'https://example.test/')
      expect(described_class.credentials_for('anthropic')).to eq(api_key: 'anthropic-key', api_base: 'https://anthropic.example/')
      expect(described_class.credentials_for('gemini')).to eq(api_key: 'gemini-key', api_base: nil)
    end
  end

  describe '.with_credentials' do
    it 'yields a RubyLLM context configured for the provider' do
      described_class.with_credentials(provider: 'anthropic', api_key: 'anthropic-key', api_base: 'https://anthropic.example') do |context|
        expect(context).to respond_to(:chat)
        expect(context.config).to respond_to(:anthropic_api_key)
        expect(context.config.anthropic_api_key).to eq('anthropic-key')
      end
    end

    it 'normalizes OpenAI-compatible endpoints' do
      described_class.with_credentials(provider: 'openai', api_key: 'local-key', api_base: 'http://localhost:11434') do |context|
        expect(context.config.openai_api_base).to eq('http://localhost:11434/v1')
      end
    end
  end
end
