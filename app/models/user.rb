class User < ApplicationRecord
  include Verification
  include DocumentValidation

  DOCUMENT_TYPES = %w(cpf rnm).freeze

  devise :database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable,
         :trackable, :validatable, :omniauthable, :password_expirable, :secure_validatable,
         authentication_keys: [:login]

  acts_as_voter
  acts_as_paranoid column: :hidden_at
  include ActsAsParanoidAliases

  include Graphqlable

  has_one :administrator
  has_one :moderator
  has_one :valuator
  has_one :manager
  has_one :editor
  has_one :poll_officer, class_name: "Poll::Officer"
  has_one :organization
  has_one :lock
  has_many :flags
  has_many :identities, dependent: :destroy
  has_many :debates, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_many :proposals, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_many :activities
  has_many :budget_investments, -> { with_hidden },
    class_name:  "Budget::Investment",
    foreign_key: :author_id,
    inverse_of:  :author
  has_many :comments, -> { with_hidden }, inverse_of: :user
  has_many :failed_census_calls
  has_many :notifications
  has_many :direct_messages_sent,
    class_name:  "DirectMessage",
    foreign_key: :sender_id,
    inverse_of:  :sender
  has_many :direct_messages_received,
    class_name:  "DirectMessage",
    foreign_key: :receiver_id,
    inverse_of:  :receiver
  has_many :legislation_answers,
    class_name: "Legislation::Answer",
    inverse_of: :user
  has_many :follows
  has_many :legislation_annotations,
    class_name:  "Legislation::Annotation",
    foreign_key: :author_id,
    inverse_of:  :author
  has_many :legislation_proposals,
    class_name:  "Legislation::Proposal",
    foreign_key: :author_id,
    inverse_of:  :author
  has_many :legislation_questions,
    class_name:  "Legislation::Question",
    foreign_key: :author_id,
    inverse_of:  :author
  has_many :legislation_topic_votes, class_name: "Legislation::TopicVote"
  has_many :polls, foreign_key: :author_id, inverse_of: :author
  has_many :poll_answers,
    class_name:  "Poll::Answer",
    foreign_key: :author_id,
    inverse_of:  :author
  has_many :poll_pair_answers,
    class_name:  "Poll::PairAnswer",
    foreign_key: :author_id,
    inverse_of:  :author
  has_many :poll_partial_results,
    class_name:  "Poll::PartialResult",
    foreign_key: :author_id,
    inverse_of:  :author
  has_many :poll_questions,
    class_name:  "Poll::Question",
    foreign_key: :author_id,
    inverse_of:  :author
  has_many :poll_recounts,
    class_name:  "Poll::Recount",
    foreign_key: :author_id,
    inverse_of:  :author
  has_many :topics, foreign_key: :author_id, inverse_of: :author
  has_many :electors, class_name: "Poll::Elector"

  belongs_to :geozone

  validates :username, presence: true, if: :username_required?
  validates :username,
    uniqueness: { case_sensitive: false },
    if: :username_required?
  validates :username, length: { minimum: 3 }, if: :username_required?
  validates :first_name, length: { minimum: 2 }, allow_nil: true
  validates :last_name, length: { minimum: 2 }, allow_nil: true
  validates :cep, length: { minimum: 8 }, allow_nil: true
  validates :address_number, length: { maximum: 7 }, allow_nil: true

  validate :username_chars_validation, if: :username_required?

  validate :first_and_last_names_chars_validation, if: :persisted?

  validates :document_number,
    uniqueness: { scope: :document_type },
    allow_nil: true,
    if: :no_disabled_user?

  validate :validate_username_length

  validate :min_user_age
  validate :max_user_age

  validates :gender, presence: true, allow_nil: true
  validates :ethnicity, presence: true, allow_nil: true
  validates :date_of_birth, presence: true, allow_nil: true
  validates :address_number, presence: true, allow_nil: true

  validate :cep_validation

  validates :official_level, inclusion: { in: 0..5 }

  validates_associated :organization, message: false

  accepts_nested_attributes_for :organization, update_only: true

  attr_accessor :skip_password_validation
  attr_accessor :use_redeemable_code
  attr_accessor :login

  scope :administrators, -> { joins(:administrator) }
  scope :editors,        -> { joins(:editor) }
  scope :moderators,     -> { joins(:moderator) }
  scope :organizations,  -> { joins(:organization) }
  scope :officials,      -> { where("official_level > 0") }
  scope :male,           -> { where(gender: "male") }
  scope :female,         -> { where(gender: "female") }
  scope :non_binary,     -> { where(gender: "non_binary") }
  scope :unknown,        -> { where(gender: "unknown") }
  scope :newsletter,     -> { where(newsletter: true) }
  scope :for_render,     -> { includes(:organization) }
  scope :by_document,    ->(document_type, document_number) do
    where(document_type: document_type, document_number: document_number)
  end
  scope :email_digest,   -> { where(email_digest: true) }
  scope :active,         -> { where(erased_at: nil) }
  scope :erased,         -> { where.not(erased_at: nil) }
  scope :public_for_api, -> { all }
  scope :by_comments,    ->(query, topics_ids) { joins(:comments).where(query, topics_ids).distinct }
  scope :by_authors,     ->(author_ids) { where("users.id IN (?)", author_ids) }
  scope :by_username_email_or_document_number, ->(search_string) do
    string = "%#{search_string}%"
    where("username ILIKE ? OR email ILIKE ? OR document_number ILIKE ?", string, string, string)
  end
  scope :between_ages, ->(from, to) do
    where(
      "date_of_birth > ? AND date_of_birth < ?",
      to.years.ago.beginning_of_year,
      from.years.ago.end_of_year
    )
  end
  scope :by_ethnicity, ->(ethnicity) { where(ethnicity: ethnicity) }

  before_validation :clean_document_number, if: :persisted?
  before_validation :clean_cep, if: :persisted?

  before_update :sanitaze_name
  before_save :document_number_changes_amount,
    unless: :document_number_changes_count
  before_save :date_of_birth_changes_amount,
    unless: :date_of_birth_changes_count
  before_save :copy_votes_from_erased_user, if: :document_number_changed?
  after_save :belongs_to_active_electoral_college,
    if: :document_number_changed?

  # Get the existing user by email if the provider gives us a verified email.
  def self.first_or_initialize_for_oauth(auth)
    oauth_email           = auth.info.email
    oauth_email_confirmed = oauth_email.present? && (auth.info.verified || auth.info.verified_email)
    oauth_user            = User.find_by(email: oauth_email) if oauth_email_confirmed

    oauth_user || User.new(
      username:  auth.info.name || auth.uid,
      email: oauth_email,
      oauth_email: oauth_email,
      password: Devise.friendly_token[0, 20],
      confirmed_at: oauth_email_confirmed ? DateTime.current : nil
    )
  end

  def name
    organization? ? organization.name : username
  end

  def debate_votes(debates)
    voted = votes.for_debates(Array(debates).map(&:id))
    voted.each_with_object({}) { |v, h| h[v.votable_id] = v.value }
  end

  def proposal_votes(proposals)
    voted = votes.for_proposals(Array(proposals).map(&:id))
    voted.each_with_object({}) { |v, h| h[v.votable_id] = v.value }
  end

  def legislation_proposal_votes(proposals)
    voted = votes.for_legislation_proposals(proposals)
    voted.each_with_object({}) { |v, h| h[v.votable_id] = v.value }
  end

  def budget_investment_votes(budget_investments)
    voted = votes.for_budget_investments(budget_investments)
    voted.each_with_object({}) { |v, h| h[v.votable_id] = v.value }
  end

  def comment_flags(comments)
    comment_flags = flags.for_comments(comments)
    comment_flags.each_with_object({}) { |f, h| h[f.flaggable_id] = true }
  end

  def voted_in_group?(group)
    votes.for_budget_investments(Budget::Investment.where(group: group)).exists?
  end

  def headings_voted_within_group(group)
    Budget::Heading.where(id: voted_investments.by_group(group).pluck(:heading_id))
  end

  def voted_investments
    Budget::Investment.where(id: votes.for_budget_investments.pluck(:votable_id))
  end

  def administrator?
    administrator.present?
  end

  def moderator?
    moderator.present?
  end

  def editor?
    editor.present?
  end

  def valuator?
    valuator.present?
  end

  def manager?
    manager.present?
  end

  def poll_officer?
    poll_officer.present?
  end

  def organization?
    organization.present?
  end

  def verified_organization?
    organization&.verified?
  end

  def official?
    official_level && official_level > 0
  end

  def incomplete_registration?
    document_number.blank?
  end

  def can_vote?
    valid? && (document_number.present? || (organization? && cep))
  end

  def add_official_position!(position, level)
    return if position.blank? || level.blank?

    update! official_position: position, official_level: level.to_i
  end

  def remove_official_position!
    update! official_position: nil, official_level: 0
  end

  def has_official_email?
    domain = Setting["email_domain_for_officials"]
    email.present? && ((email.end_with? "@#{domain}") || (email.end_with? ".#{domain}"))
  end

  def display_official_position_badge?
    return true if official_level > 1

    official_position_badge? && official_level == 1
  end

  def block
    debates_ids = Debate.where(author_id: id).pluck(:id)
    comments_ids = Comment.where(user_id: id).pluck(:id)
    proposal_ids = Proposal.where(author_id: id).pluck(:id)
    investment_ids = Budget::Investment.where(author_id: id).pluck(:id)
    proposal_notification_ids = ProposalNotification.where(author_id: id).pluck(:id)

    hide

    Debate.hide_all debates_ids
    Comment.hide_all comments_ids
    Proposal.hide_all proposal_ids
    Budget::Investment.hide_all investment_ids
    ProposalNotification.hide_all proposal_notification_ids
  end

  def erase(attrs)
    update!(
      erased_at: Time.current,
      erase_reason: attrs[:erase_reason],
      erase_reason_description: attrs[:erase_reason_description],
      username: nil,
      email: nil,
      date_of_birth: nil,
      gender: nil,
      ethnicity: nil,
      home_address: nil,
      address_number: nil,
      address_complement: nil,
      uf: nil,
      city: nil,
      cep: nil,
      geozone_id: nil,
      first_name: nil,
      last_name: nil,
      unconfirmed_email: nil,
      phone_number: nil,
      encrypted_password: "",
      confirmation_token: nil,
      reset_password_token: nil,
      email_verification_token: nil,
      confirmed_phone: nil,
      unconfirmed_phone: nil,
      email_on_comment: false,
      email_on_comment_reply: false,
      newsletter: false,
      email_digest: false,
      email_on_direct_message: false,
      recommended_debates: false,
      recommended_proposals: false
    )
    identities.destroy_all
  end

  def erased?
    erased_at.present?
  end

  def take_votes_if_erased_document(document_number, document_type)
    erased_user = User.erased.find_by(
      document_number: document_number,
      document_type: document_type
    )
    if erased_user.present?
      take_votes_from(erased_user)
      update!(former_users_data_log: data_log(erased_user))
      erased_user.update!(document_number: nil, document_type: nil)
    end
  end

  def locked?
    Lock.find_or_create_by!(user: self).locked?
  end

  def self.search(term)
    term.present? ? where("email = ? OR username ILIKE ?", term, "%#{term}%") : none
  end

  def self.username_max_length
    @username_max_length ||= columns.find { |c| c.name == "username" }.limit || 60
  end

  def self.minimum_required_age
    (Setting["min_age_to_participate"] || 16).to_i
  end

  def self.document_type_options
    DOCUMENT_TYPES.map { |type| [type.upcase, type] }
  end

  def show_welcome_screen?
    verification = Setting["feature.user.skip_verification"].present? ? true : unverified?
    sign_in_count == 1 && verification && !organization && !administrator?
  end

  def password_required?
    return false if skip_password_validation

    super
  end

  def username_required?
    !organization? && !erased?
  end

  def email_required?
    !erased? && unverified?
  end

  def locale
    self[:locale] ||= I18n.default_locale.to_s
  end

  def confirmation_required?
    super && !registering_with_oauth
  end

  def send_oauth_confirmation_instructions
    if oauth_email != email
      update(confirmed_at: nil)
      send_confirmation_instructions
    end
    update(oauth_email: nil) if oauth_email.present?
  end

  def name_and_email
    "#{name} (#{email})"
  end

  def age
    Age.in_years(date_of_birth)
  end

  def save_requiring_finish_signup
    begin
      self.registering_with_oauth = true
      save!(validate: false)
    # Devise puts unique constraints for the email the db, so we must detect & handle that
    rescue ActiveRecord::RecordNotUnique
      self.email = nil
      save!(validate: false)
    end
    true
  end

  def ability
    @ability ||= Ability.new(self)
  end
  delegate :can?, :cannot?, to: :ability

  def public_proposals
    public_activity? ? proposals : User.none
  end

  def public_debates
    public_activity? ? debates : User.none
  end

  def public_comments
    public_activity? ? comments : User.none
  end

  # overwritting of Devise method to allow login using email OR username
  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    login = conditions.delete(:login)
    where(conditions.to_hash).find_by(["lower(email) = ?", login.downcase]) ||
    where(conditions.to_hash).find_by(["username = ?", login])
  end

  def self.find_by_manager_login(manager_login)
    find_by(id: manager_login.split("_").last)
  end

  def interests
    followables = follows.map(&:followable)
    followables.compact.map { |followable| followable.tags.map(&:name) }.flatten.compact.uniq
  end

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  def foreigner_document?
    document_type == 'rnm'
  end

  private

    def clean_document_number
      return unless document_number
      self.document_number = document_number.gsub(/[^a-z0-9]+/i, "").upcase
    end

    def clean_cep
      return unless cep
      self.cep = cep.gsub(/\D/, '')
    end

    def validate_username_length
      validator = ActiveModel::Validations::LengthValidator.new(
        attributes: :username,
        maximum: User.username_max_length)
      validator.validate(self)
    end

    def min_user_age
      min_age = User.minimum_required_age
      if age && age < min_age
        message = I18n.t(
          :min_user_age,
          scope: 'activerecord.errors.models.user.attributes.date_of_birth',
          age: min_age
        )
        errors.add(:date_of_birth, message)
      end
    end

    def max_user_age
      max_age = 120
      if age && age > max_age
        message = I18n.t(
          :max_user_age,
          scope: 'activerecord.errors.models.user.attributes.date_of_birth'
        )
        errors.add(:date_of_birth, message)
      end
    end

    def username_chars_validation
      unless username =~ /[a-z\u00C0-\u017F]{3,}/i
        message = I18n.t('activerecord.errors.models.user.attributes.username')
        errors.add(:username, message)
      end
    end

    def first_and_last_names_chars_validation
      if first_name
        unless first_name =~ /^[\sa-z\u00C0-\u017F\.\-]+$/i
          errors.add(:first_name)
        end
      end

      if last_name
        unless last_name =~ /^[\sa-z\u00C0-\u017F\.\-]+$/i
          errors.add(:last_name)
        end
      end
    end

    def cep_validation
      if cep && cep.size == 8 && home_address.empty?
        errors.add(:cep, :not_found)
      end
    end

    def sanitaze_name
      self.first_name = first_name&.squish&.titleize if first_name_changed?
      self.last_name = last_name&.squish&.titleize if last_name_changed?
    end

    def document_number_changes_amount
      if changes[:document_number] && changes[:document_number][0]
        self.document_number_changes_count = 1
      end
    end

    def date_of_birth_changes_amount
      if changes[:date_of_birth] && changes[:date_of_birth][0]
        self.date_of_birth_changes_count = 1
      end
    end

    def belongs_to_active_electoral_college
      Poll::Elector.user_not_found
        .active_electoral_college
        .by_document(document_type, document_number).each do |elector|
          elector.update(user: self, user_found: true)
        end
    end

    def disabled_user
      self.class.erased.find_by(
        document_number: document_number, document_type: document_type
      )
    end

    def no_disabled_user?
      disabled_user.blank?
    end

    def copy_votes_from_erased_user
      if disabled_user.present?
        take_votes_from(disabled_user)
        self.former_users_data_log = data_log(disabled_user)
        disabled_user.update!(document_number: nil, document_type: nil)
      end
    end

    def take_votes_from(other_user)
      other_user_id = other_user.id
      Budget::Ballot.where(user_id: other_user_id).update_all(user_id: id)
      Poll::Answer.where(author_id: other_user_id).update_all(author_id: id)
      Poll::Voter.where(user_id: other_user_id).update_all(user_id: id)
      Legislation::Annotation.where(author_id: other_user_id).update_all(author_id: id)
      Legislation::Answer.where(user_id: other_user_id).update_all(user_id: id)
      Legislation::TopicVote.where(user_id: other_user_id).update_all(user_id: id)
      Vote.where("voter_id = ? AND voter_type = ?", other_user_id, "User").update_all(voter_id: id)
    end

    def data_log(other_user)
      log = "id: #{other_user.id} - #{Time.current.strftime("%Y-%m-%d %H:%M:%S")}"
      "#{former_users_data_log} | #{log}"
    end
end
