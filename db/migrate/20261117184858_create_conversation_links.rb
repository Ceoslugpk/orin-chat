class CreateConversationLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_links do |t|
      t.references :account, null: false, index: true
      t.references :conversation, null: false, index: true
      t.references :linked_conversation, null: false, index: true
      t.references :created_by, null: true, index: true

      t.timestamps
    end

    add_index :conversation_links, [:conversation_id, :linked_conversation_id], unique: true,
                                                                                 name: 'index_conversation_links_on_pair'
  end
end
