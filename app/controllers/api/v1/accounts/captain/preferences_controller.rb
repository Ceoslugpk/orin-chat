class Api::V1::Accounts::Captain::PreferencesController < Api::V1::Accounts::BaseController
  before_action :authorize_account_update, only: [:update]

  def show
    render json: preferences_payload
  end

  def update
    params_to_update = captain_params
    @current_account.captain_models = params_to_update[:captain_models] if params_to_update.key?(:captain_models)
    @current_account.captain_features = params_to_update[:captain_features] if params_to_update.key?(:captain_features)
    @current_account.captain_custom_models = params_to_update[:captain_custom_models] if params_to_update.key?(:captain_custom_models)
    @current_account.save!

    render json: preferences_payload
  end

  private

  def preferences_payload
    {
      providers: Llm::Models.providers,
      models: Llm::Models.models,
      custom_models: custom_models_payload,
      provider_configured: provider_configured_payload,
      features: features_with_account_preferences
    }
  end

  def authorize_account_update
    authorize @current_account, :update?
  end

  def captain_params
    permitted = {}
    permitted[:captain_models] = merged_captain_models if params[:captain_models].present?
    permitted[:captain_features] = merged_captain_features if params[:captain_features].present?
    permitted[:captain_custom_models] = permitted_captain_custom_models if params.key?(:captain_custom_models)
    permitted
  end

  def merged_captain_models
    existing_models = @current_account.captain_models || {}
    existing_models.merge(permitted_captain_models).compact_blank.presence
  end

  def merged_captain_features
    existing_features = @current_account.captain_features || {}
    existing_features.merge(permitted_captain_features)
  end

  def permitted_captain_models
    params.require(:captain_models).permit(*captain_feature_keys).to_h.stringify_keys
  end

  def permitted_captain_features
    params.require(:captain_features).permit(*captain_feature_keys).to_h.stringify_keys
  end

  def permitted_captain_custom_models
    Array(params[:captain_custom_models]).filter_map do |entry|
      next unless entry.respond_to?(:permit)

      entry.permit(:id, :display_name, :provider).to_h
    end
  end

  def captain_feature_keys
    Llm::Models.feature_keys.map(&:to_sym)
  end

  def features_with_account_preferences
    preferences = Current.account.captain_preferences
    account_features = preferences[:features] || {}

    Llm::Models.feature_keys.index_with do |feature_key|
      config = Llm::Models.feature_config(feature_key)
      route = Llm::FeatureRouter.resolve(feature: feature_key, account: Current.account)
      selected_model = route[:model]
      models = models_for_feature(feature_key, selected_model)

      config.merge(
        models: models,
        default: default_model_for(feature_key),
        enabled: account_features[feature_key] == true,
        model: selected_model,
        selected: selected_model,
        provider: route[:provider],
        source: route[:source]
      )
    end
  end

  def models_for_feature(feature_key, selected_model)
    models = (Llm::Models.feature_config(feature_key)[:models] || []).dup
    custom_models_for_feature.each do |custom_model|
      models << custom_model unless models.any? { |model| model[:id] == custom_model[:id] }
    end
    models << custom_model_entry(selected_model) if unlisted_selection?(models, selected_model)
    models
  end

  def unlisted_selection?(models, selected_model)
    selected_model.present? && models.none? { |model| model[:id] == selected_model }
  end

  def custom_models_for_feature
    custom_models_payload.select { |model| Llm::Models.configured_for_provider?(model[:provider]) }
  end

  def custom_models_payload
    Array(Current.account.captain_custom_models).filter_map do |model|
      id = model['id'].to_s.strip
      next if id.blank?

      provider = (model['provider'] || Llm::Models.provider_for(id)).to_s
      Llm::Models.custom_model_entry(
        id,
        display_name: model['display_name'],
        provider: provider
      )
    end
  end

  def custom_model_entry(model_name)
    Llm::Models.custom_model_entry(model_name)
  end

  def provider_configured_payload
    %w[openai anthropic gemini].index_with { |provider| Llm::Models.configured_for_provider?(provider) }
  end

  def default_model_for(feature_key)
    return Llm::FeatureRouter::CAPTAIN_V2_ASSISTANT_MODEL if feature_key == 'assistant' && Current.account.feature_enabled?('captain_integration')

    Llm::Models.default_model_for(feature_key)
  end
end
