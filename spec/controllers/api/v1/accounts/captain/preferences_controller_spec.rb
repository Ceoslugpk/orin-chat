# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::Preferences', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  describe 'GET /api/v1/accounts/{account.id}/captain/preferences' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/captain/preferences",
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns captain config' do
        get "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        expect(json_response[:features]).not_to have_key(:conversation_completion)
      end
    end

    context 'when it is an admin' do
      it 'returns captain config' do
        get "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
      end

      it 'returns effective model provider and source for each feature' do
        account.update!(captain_models: { 'editor' => 'gpt-5.1' })

        get "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :editor)).to include(
          model: 'gpt-5.1',
          selected: 'gpt-5.1',
          provider: 'openai',
          source: 'account_override'
        )
        expect(json_response.dig(:features, :help_center_query_translation)).to include(
          model: Llm::Models.default_model_for('help_center_query_translation'),
          selected: Llm::Models.default_model_for('help_center_query_translation'),
          provider: 'openai',
          source: 'default'
        )
      end

      it 'returns the assistant YAML default for V1 accounts' do
        get "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :assistant)).to include(
          default: Llm::Models.default_model_for('assistant'),
          selected: Llm::Models.default_model_for('assistant'),
          source: 'default'
        )
      end

      it 'returns GPT-5.2 as the assistant default for V2 accounts' do
        account.enable_features!('captain_integration')

        get "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :assistant)).to include(
          default: Llm::FeatureRouter::CAPTAIN_V2_ASSISTANT_MODEL,
          selected: Llm::FeatureRouter::CAPTAIN_V2_ASSISTANT_MODEL,
          source: 'default'
        )
      end

      it 'keeps the V2 assistant default when an account override is selected' do
        account.enable_features!('captain_integration')
        account.update!(captain_models: { 'assistant' => 'gpt-5.1' })

        get "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :assistant)).to include(
          default: Llm::FeatureRouter::CAPTAIN_V2_ASSISTANT_MODEL,
          selected: 'gpt-5.1',
          source: 'account_override'
        )
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/captain/preferences' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/captain/preferences",
            params: { captain_models: { editor: 'gpt-5.1' } },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns forbidden' do
        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: agent.create_new_auth_token,
            params: { captain_models: { editor: 'gpt-5.1' } },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      it 'updates captain_models' do
        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            params: { captain_models: { editor: 'gpt-5.1' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        expect(account.reload.captain_models['editor']).to eq('gpt-5.1')
      end

      it 'does not persist unknown or internal captain model feature keys' do
        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            params: {
              captain_models: {
                editor: 'gpt-5.1',
                unknown_feature: 'gpt-5.1',
                conversation_completion: 'gpt-5.1'
              }
            },
            as: :json

        expect(response).to have_http_status(:success)
        expect(account.reload.captain_models).to eq('editor' => 'gpt-5.1')
        expect(json_response[:features]).not_to have_key(:conversation_completion)
      end

      it 'rejects invalid captain model values for the feature' do
        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            params: { captain_models: { help_center_query_translation: 'gpt-5.1' } },
            as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:message]).to include('not a valid model for help_center_query_translation')
        expect(account.reload.captain_models).to be_nil
      end

      it 'removes blank captain model overrides' do
        account.update!(captain_models: { 'editor' => 'gpt-5.1' })

        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            params: { captain_models: { editor: '' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(account.reload.captain_models).to be_nil
        expect(json_response.dig(:features, :editor)).to include(
          selected: Llm::Models.default_model_for('editor'),
          source: 'default'
        )
      end

      it 'updates captain_models for document FAQ generation' do
        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            params: { captain_models: { document_faq_generation: 'gpt-5.2' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :document_faq_generation, :selected)).to eq('gpt-5.2')
        expect(account.reload.captain_models['document_faq_generation']).to eq('gpt-5.2')
      end

      it 'updates captain_models for conversation FAQ generation' do
        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            params: { captain_models: { conversation_faq_generation: 'gpt-5.1' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :conversation_faq_generation, :selected)).to eq('gpt-5.1')
        expect(account.reload.captain_models['conversation_faq_generation']).to eq('gpt-5.1')
      end

      it 'updates captain_models for PDF FAQ generation' do
        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            params: { captain_models: { pdf_faq_generation: 'gpt-5.2' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :pdf_faq_generation, :selected)).to eq('gpt-5.2')
        expect(account.reload.captain_models['pdf_faq_generation']).to eq('gpt-5.2')
      end

      it 'updates captain_features' do
        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            params: { captain_features: { editor: true } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        expect(account.reload.captain_features['editor']).to be true
      end

      it 'merges with existing captain_models' do
        account.update!(captain_models: { 'editor' => 'gpt-5.2', 'assistant' => 'gpt-5.1' })

        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            params: { captain_models: { editor: 'gpt-5.1' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        models = account.reload.captain_models
        expect(models['editor']).to eq('gpt-5.1')
        expect(models['assistant']).to eq('gpt-5.1') # Preserved
      end

      it 'merges with existing captain_features' do
        account.update!(captain_features: { 'editor' => true, 'assistant' => false })

        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            params: { captain_features: { editor: false } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        features = account.reload.captain_features
        expect(features['editor']).to be false
        expect(features['assistant']).to be false # Preserved
      end

      it 'updates both models and features in single request' do
        put "/api/v1/accounts/#{account.id}/captain/preferences",
            headers: admin.create_new_auth_token,
            params: {
              captain_models: { editor: 'gpt-5.1' },
              captain_features: { editor: true }
            },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        account.reload
        expect(account.captain_models['editor']).to eq('gpt-5.1')
        expect(account.captain_features['editor']).to be true
      end

      describe 'custom model library' do
        before do
          InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_OPEN_AI_API_KEY').update!(value: 'openai-key')
        end

        it 'returns configured provider availability' do
          get "/api/v1/accounts/#{account.id}/captain/preferences",
              headers: admin.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          expect(json_response[:provider_configured]).to eq(
            openai: true,
            anthropic: false,
            gemini: false
          )
        end

        it 'saves a custom model and returns it in the model library' do
          put "/api/v1/accounts/#{account.id}/captain/preferences",
              headers: admin.create_new_auth_token,
              params: {
                captain_custom_models: [{ id: 'local-llama', provider: 'openai' }]
              },
              as: :json

          expect(response).to have_http_status(:success)
          expect(account.reload.captain_custom_models).to eq(
            [{ 'id' => 'local-llama', 'provider' => 'openai' }]
          )
          expect(json_response[:custom_models]).to include(
            a_hash_including(id: 'local-llama', provider: 'openai', coming_soon: false)
          )
        end

        it 'offers the saved custom model for every feature' do
          account.update!(captain_custom_models: [{ 'id' => 'local-llama', 'provider' => 'openai' }])

          get "/api/v1/accounts/#{account.id}/captain/preferences",
              headers: admin.create_new_auth_token,
              as: :json

          model_ids = json_response[:features][:editor][:models].pluck(:id)
          expect(model_ids).to include('local-llama')
        end

        it 'rejects a custom model whose provider is not configured' do
          put "/api/v1/accounts/#{account.id}/captain/preferences",
              headers: admin.create_new_auth_token,
              params: {
                captain_custom_models: [{ id: 'claude-opus-4', provider: 'anthropic' }]
              },
              as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response[:message]).to include('configure Anthropic credentials or endpoint before adding claude-opus-4')
          expect(account.reload.captain_custom_models).to be_nil
        end

        it 'rejects an unknown provider' do
          put "/api/v1/accounts/#{account.id}/captain/preferences",
              headers: admin.create_new_auth_token,
              params: {
                captain_custom_models: [{ id: 'mystery-model', provider: 'acme' }]
              },
              as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response[:message]).to include('must be openai, anthropic, or gemini')
        end

        it 'removes a custom model when an empty list is submitted' do
          account.update!(captain_custom_models: [{ 'id' => 'local-llama', 'provider' => 'openai' }])

          put "/api/v1/accounts/#{account.id}/captain/preferences",
              headers: admin.create_new_auth_token,
              params: { captain_custom_models: [] },
              as: :json

          expect(response).to have_http_status(:success)
          expect(account.reload.captain_custom_models).to be_nil
          expect(json_response[:custom_models]).to eq([])
        end

        it 'ignores malformed entries instead of failing the request' do
          put "/api/v1/accounts/#{account.id}/captain/preferences",
              headers: admin.create_new_auth_token,
              params: {
                captain_custom_models: [
                  'not-a-hash',
                  { id: 'local-llama', provider: 'openai' }
                ]
              },
              as: :json

          expect(response).to have_http_status(:success)
          expect(account.reload.captain_custom_models).to eq(
            [{ 'id' => 'local-llama', 'provider' => 'openai' }]
          )
        end

        it 'keeps catalogue models in the feature list alongside custom ones' do
          account.update!(captain_custom_models: [{ 'id' => 'local-llama', 'provider' => 'openai' }])

          get "/api/v1/accounts/#{account.id}/captain/preferences",
              headers: admin.create_new_auth_token,
              as: :json

          model_ids = json_response[:features][:editor][:models].pluck(:id)
          expect(model_ids).to include('gpt-6-luna', 'local-llama')
        end
      end
    end
  end
end
