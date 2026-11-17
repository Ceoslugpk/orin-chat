require 'rails_helper'

RSpec.describe 'Super Admin settings', type: :request do
  let(:super_admin) { create(:super_admin) }

  describe 'GET /super_admin/settings' do
    it 'requires a signed-in Super Admin' do
      get '/super_admin/settings'

      expect(response).to redirect_to(new_super_admin_session_path)
    end

    %w[community enterprise].each do |plan|
      context "with a legacy #{plan} plan" do
        before do
          allow(ChatwootHub).to receive(:pricing_plan).and_return(plan)
          sign_in(super_admin, scope: :super_admin)
        end

        it 'renders the settings page without billing or plan management' do
          get '/super_admin/settings'

          expect(response).to have_http_status(:success)
          expect(response.body).to include(ChatwootHub.installation_identifier)
          expect(response.body).not_to include('hub.2.chatwoot.com')
          expect(response.body).not_to include('/super_admin/settings/refresh')
          expect(response.body).to include('Coming soon', 'Not available yet', 'Planned')
          expect(response.body).not_to include('Switch to Enterprise edition')
        end

        it 'keeps unfinished features planned rather than unlocking them for a paid plan' do
          get '/super_admin/settings'

          planned_group = response.parsed_body.css('[data-filter-group]').find do |group|
            group.at_css('h2').text == 'Coming soon'
          end

          expect(planned_group.text).to include('SAML SSO', 'Custom Branding', 'Agent Capacity', 'Disable Branding', 'Voice Calls')
          expect(planned_group.text).not_to include('Audit Logs')
          expect(planned_group.css('a')).to be_empty

          included_group = response.parsed_body.css('[data-filter-group]').find { |group| group.at_css('h2').text == 'Included' }
          expect(included_group.text).to include('Audit Logs')
        end
      end
    end
  end
end
