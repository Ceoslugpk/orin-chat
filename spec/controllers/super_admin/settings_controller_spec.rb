require 'rails_helper'

RSpec.describe 'Super Admin settings', type: :request do
  let(:super_admin) { create(:super_admin) }

  describe 'GET /super_admin/settings' do
    it 'renders the settings page without billing or plan management' do
      sign_in(super_admin, scope: :super_admin)

      get '/super_admin/settings'

      expect(response).to have_http_status(:success)
      expect(response.body).to include(ChatwootHub.installation_identifier)
      expect(response.body).not_to include('hub.2.chatwoot.com')
      expect(response.body).not_to include('/super_admin/settings/refresh')
    end
  end
end
