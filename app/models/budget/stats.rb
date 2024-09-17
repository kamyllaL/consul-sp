class Budget::Stats
  include Statisticable
  alias_method :budget, :resource

  def self.stats_methods
    super + support_phase_methods + vote_phase_methods
  end

  def self.support_phase_methods
    %i[total_participants_support_phase total_budget_investments
       total_selected_investments total_unselected_investments
       total_winner_investments total_loser_investments
       total_feasible_investments total_unfeasible_investments headings]
  end

  def self.vote_phase_methods
    %i[total_votes total_participants_vote_phase]
  end

  def stats_methods
    base_stats_methods + participation_methods + phase_methods
  end

  def phases
    types = ["vote"]
    types.unshift("support") if budget_supports.any?
    types.select { |phase| send("#{phase}_phase_finished?") }
  end

  def all_phases
    every = ["every"]
    phases.one? ? every : phases + every
  end

  def support_phase_finished?
    budget.valuating_or_later?
  end

  def vote_phase_finished?
    budget.finished?
  end

  def total_participants
    participants.distinct.count
  end

  def total_participants_support_phase
    voters.count
  end

  def total_participants_vote_phase
    (balloters + poll_ballot_voters).uniq.count
  end

  def total_budget_investments
    budget.investments.count
  end

  def total_votes
    budget.ballots.pluck(:ballot_lines_count).reduce(0) { |sum, x| sum + x }
  end

  def total_selected_investments
    budget.investments.selected.count
  end

  def total_unselected_investments
    budget.investments.unselected.count
  end

  def total_winner_investments
    budget.investments.winners.count
  end

  def total_loser_investments
    budget.investments.losers.count
  end

  def total_feasible_investments
    budget.investments.feasible.count
  end

  def total_unfeasible_investments
    budget.investments.unfeasible.count
  end

  def headings
    groups = Hash.new(0)
    budget.headings.order("id ASC").each do |heading|
      groups[heading.id] = Hash.new(0).merge(calculate_heading_totals(heading))
    end

    groups[:total] = Hash.new(0)
    groups[:total][:total_investments_count] = groups.map { |_k, v| v[:total_investments_count] }.sum
    groups[:total][:total_participants_support_phase] = groups.map { |_k, v| v[:total_participants_support_phase] }.sum
    groups[:total][:total_participants_vote_phase] = groups.map { |_k, v| v[:total_participants_vote_phase] }.sum
    groups[:total][:total_participants_every_phase] = groups.map { |_k, v| v[:total_participants_every_phase] }.sum

    budget.headings.each do |heading|
      groups[heading.id].merge!(calculate_heading_stats_with_totals(groups[heading.id], groups[:total], heading.population))
    end

    groups[:total][:percentage_participants_support_phase] = groups.map { |_k, v| v[:percentage_participants_support_phase] }.sum
    groups[:total][:percentage_participants_vote_phase] = groups.map { |_k, v| v[:percentage_participants_vote_phase] }.sum
    groups[:total][:percentage_participants_every_phase] = groups.map { |_k, v| v[:percentage_participants_every_phase] }.sum

    groups
  end

  def budget_supports
    Vote.where(votable: budget.investments)
  end

  private

    def phase_methods
      phases.map { |phase| self.class.send("#{phase}_phase_methods") }.flatten
    end

    def participant_ids
      phases.map { |phase| send("participant_ids_#{phase}_phase") }.flatten.uniq
    end

    def participant_ids_support_phase
      (authors + voters).uniq
    end

    def participant_ids_vote_phase
      (balloters + poll_ballot_voters).uniq
    end

    def authors
      @authors ||= budget.investments.pluck(:author_id)
    end

    def voters
      @voters ||= supports(budget).distinct.pluck(:voter_id)
    end

    def balloters
      @balloters ||= budget.ballots.where("ballot_lines_count > ?", 0).distinct.pluck(:user_id).compact
    end

    def poll_ballot_voters
      @poll_ballot_voters ||= budget.poll ? budget.poll.voters.pluck(:user_id) : []
    end

    def balloters_by_heading(heading_id)
      stats_cache("balloters_by_heading_#{heading_id}") do
        budget.ballots.joins(:lines)
                      .where(budget_ballot_lines: { heading_id: heading_id })
                      .distinct.pluck(:user_id)
      end
    end

    def voters_by_heading(heading)
      stats_cache("voters_by_heading_#{heading.id}") do
        supports(heading).distinct.pluck(:voter_id)
      end
    end

    def calculate_heading_totals(heading)
      {
        total_investments_count: heading.investments.count,
        total_participants_support_phase: voters_by_heading(heading).count,
        total_participants_vote_phase: balloters_by_heading(heading.id).count,
        total_participants_every_phase: voters_and_balloters_by_heading(heading)
      }
    end

    def calculate_heading_stats_with_totals(heading_totals, groups_totals, population)
      {
        percentage_participants_support_phase: participants_percent(heading_totals, groups_totals, :total_participants_support_phase),
        percentage_participants_vote_phase: participants_percent(heading_totals, groups_totals, :total_participants_vote_phase),
        percentage_participants_every_phase: participants_percent(heading_totals, groups_totals, :total_participants_every_phase),
      }
    end

    def voters_and_balloters_by_heading(heading)
      (voters_by_heading(heading) + balloters_by_heading(heading.id)).uniq.count
    end

    def participants_percent(heading_totals, groups_totals, phase)
      calculate_percentage(heading_totals[phase], groups_totals[phase])
    end

    def population_percent(population, participants)
      return "N/A" unless population.to_f.positive?

      calculate_percentage(participants, population)
    end

    def supports(supportable)
      Vote.where(votable: supportable.investments)
    end

    stats_cache(*stats_methods)

    def stats_cache(key, &block)
      Rails.cache.fetch("budgets_stats/#{budget.id}/#{phases.join}/#{key}/#{version}", &block)
    end
end
