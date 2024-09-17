class EditorLegislationProcess < ApplicationRecord
  belongs_to :editor
  belongs_to :process, class_name: "Legislation::Process", foreign_key: :legislation_process_id
end