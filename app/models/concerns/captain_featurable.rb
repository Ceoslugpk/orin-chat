# frozen_string_literal: true

module CaptainFeaturable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_captain_models
    before_validation :normalize_captain_custom_models
    # A model removed from config/llm.yml stays saved until the account is remapped, so only check changed choices.
    validate :validate_captain_models, if: :captain_models_changed?
    validate :validate_captain_custom_models, if: :captain_custom_models_changed?

    # Dynamically define accessor methods for each captain feature
    Llm::Models.feature_keys.each do |feature_key|
      # Define enabled? methods (e.g., captain_editor_enabled?)
      define_method("captain_#{feature_key}_enabled?") do
        captain_features_with_defaults[feature_key]
      end

      # Define model accessor methods (e.g., captain_editor_model)
      define_method("captain_#{feature_key}_model") do
        captain_models_with_defaults[feature_key]
      end
    end
  end

  def captain_preferences
    {
      models: captain_models_with_defaults,
      features: captain_features_with_defaults
    }.with_indifferent_access
  end

  private

  def captain_models_with_defaults
    Llm::Models.feature_keys.index_with do |feature_key|
      Llm::FeatureRouter.resolve(feature: feature_key, account: self)[:model]
    end
  end

  def captain_features_with_defaults
    stored_features = captain_features || {}
    Llm::Models.feature_keys.index_with do |feature_key|
      stored_features[feature_key] == true
    end
  end

  def validate_captain_models
    return if captain_models.blank?

    captain_models.each do |feature_key, model_name|
      unless Llm::Models.feature?(feature_key)
        errors.add(:captain_models, "'#{feature_key}' is not a known feature")
        next
      end

      next if Llm::Models.valid_model_for?(feature_key, model_name)

      errors.add(
        :captain_models,
        "'#{model_name}' is not a valid model for #{feature_key}. " \
        "Choose a catalog model or configure credentials for a custom #{Llm::Models.provider_for(model_name)} model."
      )
    end
  end

  def normalize_captain_models
    return unless captain_models.is_a?(Hash)

    normalized_models = captain_models.each_with_object({}) do |(feature_key, model_name), result|
      next if model_name.blank?

      result[feature_key.to_s] = model_name.to_s
    end

    self.captain_models = normalized_models.presence
  end

  def normalize_captain_custom_models
    return self.captain_custom_models = nil if captain_custom_models.blank?

    models = Array(captain_custom_models).filter_map { |entry| normalized_custom_model(entry) }

    self.captain_custom_models = models.uniq { |model| model['id'] }.presence
  end

  def normalized_custom_model(entry)
    return unless entry.is_a?(Hash)

    id = (entry['id'] || entry[:id]).to_s.strip
    return if id.blank?

    provider = (entry['provider'] || entry[:provider]).to_s.strip.downcase
    provider = Llm::Models.provider_for(id) if provider.blank?
    display_name = (entry['display_name'] || entry[:display_name]).to_s.strip

    {
      'id' => id,
      'display_name' => display_name.presence,
      'provider' => provider
    }.compact
  end

  def validate_captain_custom_models
    return if captain_custom_models.blank?

    captain_custom_models.each do |model|
      id = model['id'].to_s
      provider = model['provider'].to_s
      unless Llm::Models.providers.key?(provider)
        errors.add(:captain_custom_models, "provider for #{id} must be openai, anthropic, or gemini")
        next
      end

      next if Llm::Models.configured_for_provider?(provider)

      provider_label = Llm::Models.providers.dig(provider, 'display_name') || provider
      errors.add(:captain_custom_models, "configure #{provider_label} credentials or endpoint before adding #{id}")
    end
  end
end
