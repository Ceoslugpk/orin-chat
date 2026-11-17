class AddUniqueIndexToAccountSamlSettings < ActiveRecord::Migration[8.0]
  def change
    remove_index :account_saml_settings, :account_id
    add_index :account_saml_settings, :account_id, unique: true
  end
end
