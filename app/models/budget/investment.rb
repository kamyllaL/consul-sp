class Budget
  class Investment < ApplicationRecord
    SORTING_OPTIONS = { id: "id", supports: "cached_votes_up" }.freeze

    include Rails.application.routes.url_helpers
    include Measurable
    include Sanitizable
    include Taggable
    include Searchable
    include Reclassification
    include Followable
    include Communitable
    include Imageable
    include Mappable
    include Documentable

    acts_as_taggable_on :valuation_tags
    acts_as_votable
    acts_as_paranoid column: :hidden_at
    include ActsAsParanoidAliases
    include Relationable
    include Notifiable
    include Filterable
    include Flaggable
    include Milestoneable
    include Randomizable
    include FeasibilityAnalyzable

    translates :title, touch: true
    translates :description, touch: true
    include Globalizable

    audited on: [:update, :destroy]
    has_associated_audits
    translation_class.class_eval do
      audited associated_with: :globalized_model,
              only: Budget::Investment.translated_attribute_names
    end

    belongs_to :author, -> { with_hidden }, class_name: "User", inverse_of: :budget_investments
    belongs_to :heading
    belongs_to :group
    belongs_to :budget
    belongs_to :administrator

    acts_as_sequenced scope: :budget_id, column: :code

    has_many :valuator_assignments, dependent: :destroy
    has_many :valuators, through: :valuator_assignments

    has_many :valuator_group_assignments, dependent: :destroy
    has_many :valuator_groups, through: :valuator_group_assignments

    has_many :comments, -> { where(valuation: false) }, as: :commentable, inverse_of: :commentable
    has_many :valuations, -> { where(valuation: true) },
      as:         :commentable,
      inverse_of: :commentable,
      class_name: "Comment"

    delegate :name, to: :heading, prefix: true

    validates_translation :title, length: { maximum: Budget::Investment.title_max_length }
    validates_translation :description, presence: true, length: { maximum: 1200 }

    validates :author, presence: true
    validates :heading_id, presence: true
    validates :unfeasibility_explanation, presence: { if: :unfeasible_indeed? }
    validates :price, presence: { if: :price_required? }
    validates :feasibility_type, presence: { if: :feasible? }
    validates :tag_list, presence: true

    scope :sort_by_confidence_score, -> { reorder(confidence_score: :desc, id: :desc) }
    scope :sort_by_ballots,          -> { reorder(ballot_lines_count: :desc, id: :desc) }
    scope :sort_by_price,            -> { reorder(price: :desc, confidence_score: :desc, id: :desc) }
    scope :sort_by_heading, -> { order('heading_id ASC') }

    scope :sort_by_id, -> { order("id DESC") }
    scope :sort_by_supports, -> { order("cached_votes_up DESC") }

    scope :valuation_open,              -> { where(valuation_finished: false) }
    scope :without_admin,               -> { where(administrator_id: nil) }
    scope :without_valuator_group,      -> { where(valuator_group_assignments_count: 0) }
    scope :without_valuator,            -> { without_valuator_group.where(valuator_assignments_count: 0) }
    scope :under_valuation,             -> { valuation_open.valuating.where("administrator_id IS NOT ?", nil) }
    scope :managed,                     -> { valuation_open.where(valuator_assignments_count: 0).where("administrator_id IS NOT ?", nil) }
    scope :valuating,                   -> { valuation_open.where("valuator_assignments_count > 0 OR valuator_group_assignments_count > 0") }
    scope :visible_to_valuators,        -> { where(visible_to_valuators: true) }
    scope :valuation_finished,          -> { where(valuation_finished: true) }
    scope :valuation_finished_feasible, -> { where(valuation_finished: true, feasibility: "feasible") }
    scope :valuation_finished_unfeasible, -> {
      where(valuation_finished: true, feasibility: "unfeasible")
    }
    scope :feasible,                    -> { where(feasibility: "feasible") }
    scope :unfeasible,                  -> { where(feasibility: "unfeasible") }
    scope :not_unfeasible,              -> { where.not(feasibility: "unfeasible") }
    scope :undecided,                   -> { where(feasibility: "undecided") }
    scope :with_supports,               -> { where("cached_votes_up > 0") }
    scope :selected,                    -> { where(selected: true) }
    scope :compatible,                  -> { where(incompatible: false) }
    scope :incompatible,                -> { where(incompatible: true) }
    scope :winners,                     -> { selected.where(winner: true) }
    scope :losers,                      -> { selected.where(winner: false) }
    scope :unselected,                  -> { where(selected: false) }
    scope :last_week,                   -> { where("created_at >= ?", 7.days.ago) }
    scope :sort_by_flags,               -> { order(flags_count: :desc, updated_at: :desc) }
    scope :sort_by_created_at,          -> { reorder(created_at: :desc) }

    scope :by_budget,         ->(budget)      { where(budget: budget) }
    scope :by_group,          ->(group_id)    { where(group_id: group_id) }
    scope :by_heading,        ->(heading_id)  { where(heading_id: heading_id) }
    scope :by_admin,          ->(admin_id)    { where(administrator_id: admin_id) }
    scope :by_tag,            ->(tag_name)    { tagged_with(tag_name).distinct }

    scope :by_heading_slug, ->(heading_slug) do
      joins(:heading).where(budget_headings: { slug: heading_slug })
    end

    scope :for_render, -> { includes(:heading) }

    def self.by_valuator(valuator_id)
      where("budget_valuator_assignments.valuator_id = ?", valuator_id).joins(:valuator_assignments)
    end

    def self.by_valuator_group(valuator_group_id)
      joins(:valuator_group_assignments).
        where("budget_valuator_group_assignments.valuator_group_id = ?", valuator_group_id)
    end

    before_create :set_original_heading_id
    before_create :set_vote, if: :budget_vote_counting_balloting?
    before_save :calculate_confidence_score
    after_save :recalculate_heading_winners
    before_validation :set_responsible_name
    before_validation :set_denormalized_ids
    before_create :set_title, only: :create

    def comments_count
      comments.count
    end

    def self.max_feasibility_analyses_count
      select('COUNT(feasibility_analyses.id) AS analyses_count')
        .joins(:feasibility_analyses)
        .group(:id)
        .order('analyses_count DESC')
        .group('ids.ordering')
        .first&.analyses_count
    end

    def url
      budget_investment_path(budget, self)
    end

    def self.sort_by_title
      all.sort_by(&:title)
    end

    def self.filter_params(params)
      params.permit(%i[heading_id group_id administrator_id tag_name valuator_id])
    end

    def self.scoped_filter(params, current_filter)
      budget  = Budget.find_by_slug_or_id params[:budget_id]
      results = Investment.by_budget(budget)

      results = results.where("cached_votes_up + physical_votes >= ?",
                              params[:min_total_supports])                 if params[:min_total_supports].present?
      results = results.where("cached_votes_up + physical_votes <= ?",
                              params[:max_total_supports])                 if params[:max_total_supports].present?
      results = results.where(group_id: params[:group_id])                 if params[:group_id].present?
      results = results.by_tag(params[:tag_name])                          if params[:tag_name].present?
      results = results.by_tag(params[:milestone_tag_name])                if params[:milestone_tag_name].present?
      results = results.by_heading(params[:heading_id])                    if params[:heading_id].present?
      results = results.by_valuator(params[:valuator_id])                  if params[:valuator_id].present?
      results = results.by_valuator_group(params[:valuator_group_id])      if params[:valuator_group_id].present?
      results = results.by_admin(params[:administrator_id])                if params[:administrator_id].present?
      results = results.search_by_title_or_id(params[:title_or_id].strip)  if params[:title_or_id]
      results = advanced_filters(params, results)                          if params[:advanced_filters].present?

      results = results.send(current_filter) if current_filter.present?
      results.includes(:heading, :group, :budget, administrator: :user, valuators: :user)
    end

    def self.advanced_filters(params, results)
      results = results.without_admin      if params[:advanced_filters].include?("without_admin")
      results = results.without_valuator   if params[:advanced_filters].include?("without_valuator")
      results = results.under_valuation    if params[:advanced_filters].include?("under_valuation")
      results = results.valuation_finished if params[:advanced_filters].include?("valuation_finished")
      results = results.winners            if params[:advanced_filters].include?("winners")

      ids = []
      ids += results.valuation_finished_feasible.pluck(:id) if params[:advanced_filters].include?("feasible")
      ids += results.where(selected: true).pluck(:id)       if params[:advanced_filters].include?("selected")
      ids += results.undecided.pluck(:id)                   if params[:advanced_filters].include?("undecided")
      ids += results.unfeasible.pluck(:id)                  if params[:advanced_filters].include?("unfeasible")
      results = results.where("budget_investments.id IN (?)", ids) if ids.any?
      results
    end

    def self.apply_filters_and_search(budget, params, current_filter = nil)
      investments = budget.investments
      investments = investments.send(current_filter) if current_filter.present?

      if params[:heading_id].present?
        investments = investments.by_heading(params[:heading_id])
      elsif params[:heading_slug].present?
        investments = investments.by_heading_slug(params[:heading_slug])
      end
      if params[:search].present?
        search_by_id = investments.where(id: params[:search])
        if search_by_id.any?
          investments = search_by_id
        else
          investments = investments.search(params[:search])
        end
      end
      if params[:advanced_search].present?
        investments = investments.filter(params[:advanced_search])
      end
      if params[:tag].present?
        investments = investments.tagged_with(params[:tag])
      end
      if params[:status_filters]&.any?
        investments =
          investments.status_filters(params[:status_filters], investments)
      end

      investments
    end

    def self.status_filters(filters, results)
      return results if filters.include?('all')

      if (filters & ['selected', 'unselected', 'winners', 'losers']).any?
        balloting_ids = []
        if filters.include?('selected')
          balloting_ids += results.selected.pluck(:id)
        end
        if filters.include?('unselected')
          balloting_ids += results.unselected.pluck(:id)
        end
        if filters.include?('winners')
          balloting_ids += results.winners.pluck(:id)
        end
        if filters.include?('losers')
          balloting_ids += results.losers.pluck(:id)
        end
        results = results.where("budget_investments.id IN (?)", balloting_ids)
      end

      if (filters & ['feasibles', 'unfeasibles']).any?
        feasibility_ids = []
        if filters.include?('feasibles')
          feasibility_ids += results.valuation_finished_feasible.pluck(:id)
        end
        if filters.include?('unfeasibles')
          feasibility_ids += results.valuation_finished_unfeasible.pluck(:id)
        end
        results = results.where("budget_investments.id IN (?)", feasibility_ids)
      end

      results
    end

    def self.order_filter(params)
      sorting_key = params[:sort_by]&.downcase&.to_sym
      allowed_sort_option = SORTING_OPTIONS[sorting_key]
      direction = params[:direction] == "desc" ? "desc" : "asc"

      if allowed_sort_option.present?
        order("#{allowed_sort_option} #{direction}")
      elsif sorting_key == :title
        direction == "asc" ? sort_by_title : sort_by_title.reverse
      else
        order(cached_votes_up: :desc).order(id: :desc)
      end
    end

    def self.limit_results(budget, params, results)
      max_per_heading = params[:max_per_heading].to_i
      return results if max_per_heading <= 0

      ids = []
      budget.headings.pluck(:id).each do |hid|
        ids += Investment.where(heading_id: hid).order(confidence_score: :desc).limit(max_per_heading).pluck(:id)
      end

      results.where("budget_investments.id IN (?)", ids)
    end

    def self.search_by_title_or_id(title_or_id)
      with_joins = with_translations(Globalize.fallbacks(I18n.locale))

      with_joins.where(id: title_or_id).
        or(with_joins.where("budget_investment_translations.title ILIKE ?", "%#{title_or_id}%"))
    end

    def searchable_values
      { author.username    => "B",
        heading.name       => "B",
        tag_list.join(" ") => "B"
      }.merge(searchable_globalized_values)
    end

    def self.search(terms)
      pg_search(terms)
    end

    def self.by_heading(heading)
      where(heading_id: heading == "all" ? nil : heading.presence)
    end

    def undecided?
      feasibility == "undecided"
    end

    def feasible?
      feasibility == "feasible"
    end

    def unfeasible?
      feasibility == "unfeasible"
    end

    def feasible_indeed?
      feasible? && valuation_finished?
    end

    def unfeasible_indeed?
      unfeasible? && valuation_finished?
    end

    def price_required?
      feasible? && valuation_finished? && budget_resource_allocation_balloting?
    end

    def total_votes
      if budget_vote_counting_balloting?
        ballot_lines_count
      else
        cached_votes_up + physical_votes
      end
    end

    def reason_for_not_being_selectable_by(user)
      return permission_problem(user) if permission_problem?(user)
      return :different_heading_assigned unless valid_heading?(user)

      return :no_selecting_allowed unless budget.selecting?
    end

    def reason_for_not_being_ballotable_by(user, ballot)
      return permission_problem(user) if permission_problem?(user)
      return :not_selected unless selected?
      return :no_ballots_allowed unless budget.balloting?
      return :different_heading_assigned unless ballot.valid_heading?(heading)
      if ballot.present?
        if budget_vote_counting_balloting? && !enough_vote?(ballot)
          return :not_enough_vote
        elsif budget_resource_allocation_balloting? && !enough_money?(ballot)
          return :not_enough_money
        end
      end
      return :casted_offline if ballot.casted_offline?
    end

    def permission_problem(user)
      return :not_logged_in unless user
      return :organization  if user.organization?
      return :incomplete_registration if user.incomplete_registration?
      return :not_verified  unless user.can?(:vote, Budget::Investment)

      nil
    end

    def permission_problem?(user)
      permission_problem(user).present?
    end

    def selectable_by?(user)
      reason_for_not_being_selectable_by(user).blank?
    end

    def valid_heading?(user)
      voted_in?(heading, user) ||
      can_vote_in_another_heading?(user)
    end

    def can_vote_in_another_heading?(user)
      user.headings_voted_within_group(group).count < group.max_votable_headings
    end

    def voted_in?(heading, user)
      user.headings_voted_within_group(group).where(id: heading.id).exists?
    end

    def ballotable_by?(user)
      reason_for_not_being_ballotable_by(user).blank?
    end

    def enough_money?(ballot)
      available_money = ballot.amount_available(heading)
      price.to_i <= available_money
    end

    def enough_vote?(ballot)
      ballot.amount_available > 0
    end

    def register_selection(user)
      vote_by(voter: user, vote: "yes") if selectable_by?(user)
    end

    def calculate_confidence_score
      self.confidence_score = ScoreCalculator.confidence_score(total_votes, total_votes)
    end

    def recalculate_heading_winners
      Budget::Result.new(budget, heading).calculate_winners if saved_change_to_incompatible?
    end

    def set_responsible_name
      self.responsible_name = author&.document_number if author&.document_number.present?
    end

    def budget_resource_allocation_balloting?
      budget.resource_allocation_balloting?
    end

    def budget_vote_counting_balloting?
      budget.vote_counting_balloting?
    end

    def should_show_votes?
      budget.selecting?
    end

    def should_show_vote_count?
      budget.valuating_or_later?
    end

    def should_show_ballots?
      budget.balloting? && selected?
    end

    def should_show_price?
      budget_resource_allocation_balloting? &&
        selected? &&
        price.present? &&
        budget.published_prices?
    end

    def should_show_price_explanation?
      budget_resource_allocation_balloting? &&
        should_show_price? &&
        price_explanation.present?
    end

    def should_show_unfeasibility_explanation?
      unfeasible? && valuation_finished? && unfeasibility_explanation.present?
    end

    def should_show_feasibility_analysis?
      selected? &&
        valuation_finished? &&
        !undecided? &&
        budget.devolutive_or_later?
    end

    def formatted_price
      if budget_resource_allocation_balloting?
        budget.formatted_currency_amount(price)
      end
    end

    def assigned_valuators
      self.valuators.map(&:description_or_name).compact.join(", ").presence
    end

    def assigned_valuation_groups
      self.valuator_groups.map(&:name).compact.join(", ").presence
    end

    def self.with_milestone_status_id(status_id)
      includes(milestones: :translations).select do |investment|
        investment.milestone_status_id == status_id.to_i
      end
    end

    def milestone_status_id
      milestones.published.with_status.order_by_publication_date.last&.status_id
    end

    def admin_and_valuator_users_associated
      valuator_users = (valuator_groups.map(&:valuators) + valuators).flatten
      all_users = valuator_users << administrator
      all_users.compact.uniq
    end

    private

      def set_title
        self.title = code
      end

      def set_denormalized_ids
        self.group_id = heading&.group_id if will_save_change_to_heading_id?
        self.budget_id ||= heading&.group&.budget_id
      end

      def set_original_heading_id
        self.original_heading_id = heading_id
      end

      def set_vote
        self.price = 1
      end

      def searchable_translations_definitions
        { title       => "A",
          description => "D" }
      end
  end
end
