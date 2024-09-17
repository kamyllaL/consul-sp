class LocalCensusRecord < ApplicationRecord
  include DocumentValidation

  before_validation :sanitize

  validates :document_number, presence: true
  validates :document_type, presence: true
  validates :document_type, inclusion: {
    in: User::DOCUMENT_TYPES, allow_blank: true
  }
  validates :postal_code, length: { is: 8 }, allow_blank: true
  validates :document_number, uniqueness: { scope: :document_type }
  validates :gender, inclusion: {
    in: ->(record) { record.class.valid_gender_options }, allow_blank: true
  }
  validates :ethnicity, inclusion: {
    in: ->(record) { record.class.valid_ethnicity_options }, allow_blank: true
  }
  validate :valid_date_of_birth

  scope :search, ->(terms) { where("document_number ILIKE ?", "%#{terms}%") }

  attr_accessor :invalid_date

  def self.valid_gender_options
    gender_values.values.map(&:to_s)
  end

  def self.valid_ethnicity_options
    ethnicity_values.values.map(&:to_s)
  end

  def self.gender_options
    gender_values.keys.map(&:downcase)
  end

  def self.ethnicity_options
    ethnicity_values.keys.map(&:downcase)
  end

  private

    def sanitize
      self.document_type = self.document_type&.downcase&.strip
      self.document_number = self.document_number&.strip
      self.postal_code = self.postal_code&.strip
      set_gender if gender.present?
      set_ethnicity if ethnicity.present?
    end

    def self.gender_values
      local_census_record_translation_attr(:gender_options).invert
    end

    def self.ethnicity_values
      local_census_record_translation_attr(:ethnicity_options).invert
    end

    def self.local_census_record_translation_attr(attr_key)
      I18n.t(attr_key, scope: 'activerecord.attributes.local_census_record')
    end

    def set_gender
      return if self.class.valid_gender_options.include? gender
      if value = self.class.gender_values[gender.capitalize]
        self.gender = value
      end
    end

    def set_ethnicity
      return if self.class.valid_ethnicity_options.include? ethnicity
      if value = self.class.ethnicity_values[ethnicity.capitalize]
        self.ethnicity = value
      end
    end

    def valid_date_of_birth
      return unless invalid_date
      message = I18n.t("admin.local_census_records.errors.invalid_date")
      errors.add(:invalid_date, message)
    end
end
