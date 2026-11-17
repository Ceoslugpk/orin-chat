# == Schema Information
#
# Table name: team_members
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_team_members_on_team_id              (team_id)
#  index_team_members_on_team_id_and_user_id  (team_id,user_id) UNIQUE
#  index_team_members_on_user_id              (user_id)
#
class TeamMember < ApplicationRecord
  belongs_to :user
  belongs_to :team
  delegate :account, to: :team, allow_nil: true
  validates :user_id, uniqueness: { scope: :team_id }

  after_commit :invalidate_filtered_unread_count_visibility, on: [:create, :destroy]
  after_commit :notify_permissions_changed, on: [:create, :destroy]

  private

  def invalidate_filtered_unread_count_visibility
    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(team&.account).user_visibility_changed!(user_id: user_id)
  end

  def notify_permissions_changed
    account = team&.account
    return unless account&.feature_enabled?('custom_roles')

    Rails.configuration.dispatcher.dispatch(ACCOUNT_PERMISSIONS_CHANGED, Time.zone.now, account: account, user_id: user_id)
  end
end

TeamMember.include_mod_with('Audit::TeamMember')
