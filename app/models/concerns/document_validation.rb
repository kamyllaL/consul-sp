module DocumentValidation
  extend ActiveSupport::Concern

  included do
    validate :valid_document_number
  end

  def valid_document_number
    return if document_number.blank? || document_type.blank?

    if invalid_cpf? || invalid_rnm?
      message = I18n.t(
        :invalid_number,
        scope: 'activerecord.errors.models.user.attributes.cpf'
      )
      errors.add(:document_number, message)
    end
  end

  def invalid_cpf?
    document_type.downcase == 'cpf' && !CPF.valid?(document_number)
  end

  def invalid_rnm?
    document_type.downcase == 'rnm' && !(document_number =~ /^[A-Z]\d{6}[A-Z]$/)
  end
end
