class Poll
  class Elector < ApplicationRecord
    include DocumentValidation

    before_validation :sanitize
    before_validation :set_user

    belongs_to :electoral_college,
      class_name: "Poll::ElectoralCollege",
      foreign_key: "poll_electoral_college_id"

    belongs_to :user

    validates :document_type, presence: true
    validates :document_type,
      inclusion: { in: User::DOCUMENT_TYPES, allow_blank: true }

    validates :document_number, presence: true
    validates :document_number,
      uniqueness: { scope: [:electoral_college, :category] }

    scope :user_not_found, -> { where(user_found: false) }
    scope :by_category, ->(category) { where(category: category) }
    scope :active_electoral_college, -> do
      joins(:electoral_college).where(poll_electoral_colleges: { active: true })
    end
    scope :by_document, ->(document_type, document_number) do
      where(document_type: document_type, document_number: document_number)
    end
    scope :by_electoral_college, ->(electoral_college) do
      where(electoral_college: electoral_college)
    end

    def self.search(terms)
      where("document_number ILIKE ?", "%#{terms}%")
    end

    def self.quick_search(terms)
      if terms.blank?
        Elector.none
      else
        search(terms)
      end
    end

    private

    def sanitize
      self.document_type = document_type&.downcase&.strip
      self.document_number = clean_document_number
      self.category = category&.capitalize&.strip
    end

    def clean_document_number
      return unless document_number
      self.document_number = document_number.gsub(/[^a-z0-9]+/i, "").upcase
    end

    def set_user
      if user = find_user
        self.user = user
        self.user_found = true
      end
    end

    def find_user
      if document_type.present? && document_number.present?
        User.find_by(
          document_type: document_type,
          document_number: document_number
        )
      end
    end

  end
end
