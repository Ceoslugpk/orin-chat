require 'rails_helper'

describe ChatwootHub do
  describe '.base_url' do
    it 'uses the static hub url' do
      expect(described_class::DEFAULT_BASE_URL).to eq('https://hub.2.chatwoot.com')
      expect(described_class.base_url).to eq('https://hub.2.chatwoot.com')
    end
  end

  it 'generates installation identifier' do
    installation_identifier = described_class.installation_identifier
    expect(installation_identifier).not_to be_nil
    expect(described_class.installation_identifier).to eq installation_identifier
  end

  it 'does not offer version pings, instance registration or telemetry events' do
    %i[sync_with_hub register_instance emit_event instance_metrics billing_url].each do |method_name|
      expect(described_class).not_to respond_to(method_name)
    end
  end

  context 'when relaying a push notification' do
    let(:fcm_options) { { token: 'device-token' } }

    it 'posts the notification to the hub push endpoint' do
      allow(RestClient).to receive(:post)
      described_class.send_push(fcm_options)
      expect(RestClient).to have_received(:post).with(described_class.push_notification_url,
                                                      { fcm_options: fcm_options }.merge(described_class.instance_config).to_json,
                                                      { content_type: :json, accept: :json })
    end

    it 'does not raise when the hub is down' do
      allow(RestClient).to receive(:post).and_raise(ExceptionList::REST_CLIENT_EXCEPTIONS.sample)
      expect { described_class.send_push(fcm_options) }.not_to raise_error
    end
  end
end
