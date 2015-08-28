ActiveRecord::Schema.define version: 0 do
  create_table :videos, force: true do |t|
    t.string  :asset_file_name
    t.string  :asset_content_type
    t.integer :asset_updated_at
    t.integer :asset_file_size
  end
end
