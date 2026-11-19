# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CaptainFeaturable do
  let(:account) { create(:account) }

  describe 'dynamic method generation' do
    it 'generates enabled? methods for all features' do
      Llm::Models.feature_keys.each do |feature_key|
        expect(account).to respond_to("captain_#{feature_key}_enabled?")
      end
    end

    it 'generates model accessor methods for all features' do
      Llm::Models.feature_keys.each do |feature_key|
        expect(account).to respond_to("captain_#{feature_key}_model")
      end
    end
  end

  describe 'feature enabled methods' do
    context 'when no features are explicitly enabled' do
      it 'returns false for all features' do
        Llm::Models.feature_keys.each do |feature_key|
          expect(account.send("captain_#{feature_key}_enabled?")).to be false
        end
      end
    end

    context 'when features are explicitly enabled' do
      before do
        account.update!(captain_features: { 'editor' => true, 'assistant' => true })
      end

      it 'returns true for enabled features' do
        expect(account.captain_editor_enabled?).to be true
        expect(account.captain_assistant_enabled?).to be true
      end

      it 'returns false for disabled features' do
        expect(account.captain_copilot_enabled?).to be false
        expect(account.captain_help_center_query_translation_enabled?).to be false
      end
    end

    context 'when captain_features is nil' do
      before do
        account.update!(captain_features: nil)
      end

      it 'returns false for all features' do
        Llm::Models.feature_keys.each do |feature_key|
          expect(account.send("captain_#{feature_key}_enabled?")).to be false
        end
      end
    end
  end

  describe 'model accessor methods' do
    context 'when models are explicitly configured' do
      before do
        account.update!(captain_models: {
                          'editor' => 'gpt-5.1',
                          'assistant' => 'gpt-5.1',
                          'help_center_query_translation' => 'gpt-6-luna'
                        })
      end

      it 'returns configured models for configured features' do
        expect(account.captain_editor_model).to eq('gpt-5.1')
        expect(account.captain_assistant_model).to eq('gpt-5.1')
        expect(account.captain_help_center_query_translation_model).to eq('gpt-6-luna')
      end

      it 'returns default models for unconfigured features' do
        expect(account.captain_copilot_model).to eq(Llm::Models.default_model_for('copilot'))
        expect(account.captain_audio_transcription_model).to eq(Llm::Models.default_model_for('audio_transcription'))
      end
    end

    context 'when configured with invalid model' do
      before do
        account.captain_models = { 'editor' => 'invalid-model' }
      end

      it 'falls back to default model' do
        expect(account.captain_editor_model).to eq(Llm::Models.default_model_for('editor'))
      end

      it 'rejects the change but still saves other attributes once stored' do
        expect(account).not_to be_valid

        account.save(validate: false)
        expect(account.reload.update(name: 'Renamed')).to be(true)
      end
    end

    context 'when captain_models is nil' do
      before do
        account.update!(captain_models: nil)
      end

      it 'returns default models for all features' do
        Llm::Models.feature_keys.each do |feature_key|
          expected_default = Llm::Models.default_model_for(feature_key)
          expect(account.send("captain_#{feature_key}_model")).to eq(expected_default)
        end
      end
    end
  end

  describe 'custom model library' do
    before do
      InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_OPEN_AI_API_KEY').update!(value: 'openai-key')
      InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_ANTHROPIC_API_KEY').update!(value: 'anthropic-key')
    end

    it 'normalizes entries and infers a missing provider from the model name' do
      account.update!(captain_custom_models: [
                        { id: '  local-llama  ', display_name: '  Llama  ' },
                        { 'id' => 'claude-custom' }
                      ])

      expect(account.reload.captain_custom_models).to eq(
        [
          { 'id' => 'local-llama', 'display_name' => 'Llama', 'provider' => 'openai' },
          { 'id' => 'claude-custom', 'provider' => 'anthropic' }
        ]
      )
    end

    it 'drops duplicate ids and blank entries' do
      account.update!(captain_custom_models: [
                        { id: 'local-llama', provider: 'openai' },
                        { id: 'local-llama', provider: 'openai' },
                        { id: '   ', provider: 'openai' }
                      ])

      expect(account.reload.captain_custom_models).to eq(
        [{ 'id' => 'local-llama', 'provider' => 'openai' }]
      )
    end

    it 'clears the library when it is blank' do
      account.update!(captain_custom_models: [{ id: 'local-llama', provider: 'openai' }])
      account.update!(captain_custom_models: [])

      expect(account.reload.captain_custom_models).to be_nil
    end

    it 'rejects a provider that has no credentials or endpoint' do
      account.captain_custom_models = [{ id: 'gemini-custom', provider: 'gemini' }]

      expect(account).not_to be_valid
      expect(account.errors.full_messages.join).to include('configure Gemini credentials or endpoint before adding gemini-custom')
    end

    it 'rejects an unknown provider' do
      account.captain_custom_models = [{ id: 'mystery', provider: 'acme' }]

      expect(account).not_to be_valid
      expect(account.errors.full_messages.join).to include('must be openai, anthropic, or gemini')
    end
  end

  describe 'integration with existing captain_preferences' do
    it 'enabled? methods use the same logic as captain_preferences[:features]' do
      account.update!(captain_features: { 'editor' => true, 'copilot' => true })
      prefs = account.captain_preferences

      Llm::Models.feature_keys.each do |feature_key|
        expect(account.send("captain_#{feature_key}_enabled?")).to eq(prefs[:features][feature_key])
      end
    end

    it 'model methods use the same logic as captain_preferences[:models]' do
      account.update!(captain_models: { 'editor' => 'gpt-5.1', 'assistant' => 'gpt-5.2' })
      prefs = account.captain_preferences

      Llm::Models.feature_keys.each do |feature_key|
        expect(account.send("captain_#{feature_key}_model")).to eq(prefs[:models][feature_key])
      end
    end
  end
end
