class AddDifferenceExplanationToPollRecounts < ActiveRecord::Migration[5.1]
  def change
    add_column :poll_recounts, :difference_explanation, :text
  end
end
