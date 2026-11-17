class Conversations::RequiredAttributesService
  def initialize(conversation)
    @conversation = conversation
  end

  def required_keys
    return [] unless conversation.account.feature_enabled?('conversation_required_attributes')

    Array(conversation.account.settings['conversation_required_attributes']).map(&:to_s).compact_blank
  end

  def missing_attributes
    custom_attributes = conversation.custom_attributes || {}
    required_keys.select do |key|
      definition = definitions[key]
      definition.present? && value_missing?(custom_attributes[key], definition)
    end
  end

  private

  attr_reader :conversation

  def definitions
    @definitions ||= conversation.account.custom_attribute_definitions
                                 .conversation_attribute
                                 .where(attribute_key: required_keys)
                                 .index_by(&:attribute_key)
  end

  def value_missing?(value, definition)
    return value.nil? if definition.checkbox?

    value.nil? || value.to_s.strip.empty?
  end
end
