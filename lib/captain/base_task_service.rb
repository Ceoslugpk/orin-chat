class Captain::BaseTaskService
  include Integrations::LlmInstrumentation
  include Captain::ToolInstrumentation
  include Llm::ExceptionTrackable

  # Sized for a 128,000-token context window
  # 1 token is approx 4 characters
  # sticking with 120000 to be safe
  # 120000 * 4 = 480,000 characters (rounding off downwards to 400,000 to be safe)
  TOKEN_LIMIT = 400_000
  GPT_MODEL = Llm::Config::DEFAULT_MODEL

  # Prepend enterprise module to subclasses when they're defined.
  # This ensures the enterprise perform wrapper is applied even when
  # subclasses define their own perform method, since prepend puts
  # the module before the class in the ancestor chain.
  def self.inherited(subclass)
    super
    subclass.prepend_mod_with('Captain::BaseTaskService')
  end

  pattr_initialize [:account!, { conversation_display_id: nil }]

  private

  def event_name
    raise NotImplementedError, "#{self.class} must implement #event_name"
  end

  def conversation
    @conversation ||= account.conversations.find_by(display_id: conversation_display_id)
  end

  def make_api_call(messages:, model: nil, feature: nil, schema: nil, tools: [])
    # Community edition prerequisite checks
    # Enterprise module handles these with more specific error messages (cloud vs self-hosted)
    return { error: I18n.t('captain.disabled'), error_code: 403 } unless captain_tasks_enabled?

    provider = resolved_provider(model: model, feature: feature)
    credential = llm_credential(provider: provider)
    return { error: I18n.t('captain.api_key_missing'), error_code: 401 } unless api_key_configured?(credential)

    resolved_model_name = resolved_model(model: model, feature: feature)
    instrumentation_params = build_instrumentation_params(resolved_model_name, messages, feature: feature)
    instrumentation_method = tools.any? ? :instrument_tool_session : :instrument_llm_call

    response = send(instrumentation_method, instrumentation_params) do
      execute_ruby_llm_request(
        model: resolved_model_name,
        provider: provider,
        messages: messages,
        schema: schema,
        tools: tools,
        feature: feature,
        credential: credential
      )
    end

    return response unless build_follow_up_context? && response[:message].present?

    response.merge(follow_up_context: build_follow_up_context(messages, response))
  end

  def resolved_model(model:, feature:)
    return model if feature.blank?

    route = Llm::FeatureRouter.resolve(feature: feature, account: account)
    return model if model.present? && route[:source] == :default

    route[:model]
  end

  def resolved_provider(model:, feature:)
    if feature.present?
      route = Llm::FeatureRouter.resolve(feature: feature, account: account)
      return route[:provider] if model.blank? || route[:source] != :default
    end

    Llm::Models.provider_for(model) || 'openai'
  end

  def execute_ruby_llm_request(model:, provider:, messages:, schema: nil, tools: [], feature: nil, credential: nil)
    credential ||= llm_credential(provider: provider)

    with_llm_context(provider: provider, credential: credential) do |context|
      chat = build_chat(context, model: model, messages: messages, schema: schema, tools: tools, feature: feature)

      conversation_messages = messages.reject { |m| m[:role] == 'system' }
      return { error: 'No conversation messages provided', error_code: 400, request_messages: messages } if conversation_messages.empty?

      add_messages_if_needed(chat, conversation_messages)
      build_ruby_llm_response(chat.ask(conversation_messages.last[:content]), messages, schema: schema)
    end
  rescue StandardError => e
    capture_llm_exception(e, credential: credential)
    { error: e.message, request_messages: messages }
  end

  def with_llm_context(provider:, credential:, &)
    if provider.to_s == 'openai'
      Llm::Config.with_api_key(credential[:api_key], api_base: credential[:api_base], &)
    else
      Llm::Config.with_credentials(provider: provider, api_key: credential[:api_key], api_base: credential[:api_base], &)
    end
  end

  def build_chat(context, model:, messages:, **request)
    tools = request.fetch(:tools, [])
    options = Captain::ResponsesConfig.options(model: model, temperature: nil, feature: request[:feature])
    chat = context.chat(model: model, **options.slice(:protocol))
    chat.with_thinking(**options[:thinking]) if options[:thinking]
    system_msg = messages.find { |m| m[:role] == 'system' }
    chat.with_instructions(system_msg[:content]) if system_msg
    chat.with_schema(request[:schema]) if request[:schema]

    if tools.any?
      tools.each { |tool| chat = chat.with_tools(tool) }
      chat.after_message { |message| record_generation(chat, message, model) }
    end

    chat
  end

  def add_messages_if_needed(chat, conversation_messages)
    return if conversation_messages.length == 1

    conversation_messages[0...-1].each do |msg|
      chat.add_message(role: msg[:role].to_sym, content: msg[:content])
    end
  end

  def build_ruby_llm_response(response, messages, schema: nil)
    {
      message: schema ? response.parsed : response.content,
      usage: {
        'prompt_tokens' => response.tokens.input,
        'completion_tokens' => response.tokens.output,
        'total_tokens' => (response.tokens.input || 0) + (response.tokens.output || 0),
        'reasoning_tokens' => response.tokens.thinking
      }.compact,
      request_messages: messages
    }
  end

  def build_instrumentation_params(model, messages, feature: nil)
    {
      span_name: "llm.#{event_name}",
      account_id: account.id,
      conversation_id: conversation&.display_id,
      feature_name: event_name,
      model: model,
      messages: messages,
      temperature: nil,
      metadata: instrumentation_metadata.merge(Captain::ResponsesConfig.request_metadata(model: model, feature: feature))
    }
  end

  def instrumentation_metadata
    {
      channel_type: conversation&.inbox&.channel_type
    }.compact
  end

  def conversation_messages(start_from: 0)
    messages = []
    character_count = start_from

    conversation.messages
                .where(message_type: [:incoming, :outgoing])
                .where(private: false)
                .reorder('id desc')
                .each do |message|
      content = message.content_for_llm
      next if content.blank?
      break if character_count + content.length > TOKEN_LIMIT

      messages.prepend({ role: (message.incoming? ? 'user' : 'assistant'), content: content })
      character_count += content.length
    end

    messages
  end

  def captain_tasks_enabled?
    account.feature_enabled?('captain_tasks')
  end

  # Extension point consulted by the Enterprise quota wrapper. Subclasses
  # whose calls should not consume captain_responses should override this to
  # return false. When false, the wrapper neither blocks the call on an
  # exhausted captain_responses quota nor decrements it on success — the call
  # participates in the quota system in neither direction.
  def counts_toward_usage?
    llm_credential&.dig(:source) != :hook
  end

  def api_key_configured?(credential = nil)
    credential ||= llm_credential
    return true if credential&.dig(:source) == :hook

    provider = (credential&.dig(:provider) || 'openai').to_s
    if provider == 'openai'
      return credential&.dig(:api_key).present? if custom_openai_endpoint_blank?

      return credential&.dig(:api_key).present? || credential&.dig(:api_base).present?
    end

    credential&.dig(:api_key).present?
  end

  def custom_openai_endpoint_blank?
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    endpoint.blank? || endpoint.to_s.chomp('/') == LlmConstants::OPENAI_API_ENDPOINT
  end

  def api_key(provider = 'openai')
    llm_credential(provider: provider)&.dig(:api_key)
  end

  def llm_credential(provider: 'openai')
    @llm_credentials ||= {}
    @llm_credentials[provider.to_s] ||= if use_account_openai_hook? && provider.to_s == 'openai'
                                          hook_llm_credential || system_llm_credential('openai')
                                        else
                                          system_llm_credential(provider)
                                        end
  end

  def use_account_openai_hook?
    false
  end

  def hook_llm_credential
    key = openai_hook&.settings&.dig('api_key').presence
    return unless key

    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence
    { api_key: key, api_base: endpoint, provider: 'openai', source: :hook }
  end

  def system_llm_credential(provider)
    credentials = Llm::Config.credentials_for(provider)
    api_key = credentials[:api_key].presence
    api_base = credentials[:api_base].presence
    if provider.to_s == 'openai'
      return if api_key.blank? && custom_openai_endpoint_blank?
    elsif api_key.blank?
      return
    end

    { api_key: api_key, api_base: api_base, provider: provider.to_s, source: :system }
  end

  def openai_hook
    @openai_hook ||= account.hooks.find_by(app_id: 'openai', status: 'enabled')
  end

  def exception_tracking_account
    account
  end

  def prompt_from_file(file_name)
    Rails.root.join('lib/integrations/openai/openai_prompts', "#{file_name}.liquid").read
  end

  # Follow-up context for client-side refinement
  def build_follow_up_context?
    # FollowUpService should return its own updated context
    !is_a?(Captain::FollowUpService)
  end

  def build_follow_up_context(messages, response)
    {
      event_name: event_name,
      original_context: extract_original_context(messages),
      last_response: response[:message],
      conversation_history: [],
      channel_type: conversation&.inbox&.channel_type
    }
  end

  def extract_original_context(messages)
    # Get the most recent user message for follow-up context
    user_msg = messages.reverse.find { |m| m[:role] == 'user' }
    user_msg ? user_msg[:content] : nil
  end
end
Captain::BaseTaskService.prepend_mod_with('Captain::BaseTaskService')
