class Poll::Recount < ApplicationRecord
  VALID_ORIGINS = %w[web booth letter].freeze

  belongs_to :author, -> { with_hidden }, class_name: "User", inverse_of: :poll_recounts
  belongs_to :booth_assignment
  belongs_to :officer_assignment

  has_many :voters, through: :booth_assignment

  validates :author, presence: true
  validates :origin, inclusion: { in: VALID_ORIGINS }
  validate :match_voters_and_ballots

  scope :web,    -> { where(origin: "web") }
  scope :booth,  -> { where(origin: "booth") }
  scope :letter, -> { where(origin: "letter") }

  scope :by_author, ->(author_id) { where(author_id: author_id) }

  before_save :update_logs

  delegate :booth_name, to: :booth_assignment

  def update_logs
    amounts_changed = false

    [:white, :null, :total].each do |amount|
      next unless send("will_save_change_to_#{amount}_amount?") && send("#{amount}_amount_in_database").present?

      self["#{amount}_amount_log"] += ":#{send("#{amount}_amount_in_database")}"
      amounts_changed = true
    end

    update_officer_author if amounts_changed
  end

  def update_officer_author
    self.officer_assignment_id_log += ":#{officer_assignment_id_in_database}"
    self.author_id_log += ":#{author_id_in_database}"
  end

  def match_voters_and_ballots
    return if voters.empty?
    if total_amount > voters.size && difference_explanation.blank?
      errors.add(:total_amount)
    end
  end
end
