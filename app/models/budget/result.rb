class Budget
  class Result
    attr_accessor :budget, :heading, :current_investment

    def initialize(budget, heading)
      @budget = budget
      @heading = heading
    end

    def calculate_winners
      reset_winners

      if budget.vote_counting_balloting?
        vote_counting_winners.each do |investment|
          investment.update!(winner: true, visible_to_valuators: true)
        end
      else
        investments.compatible.each do |investment|
          @current_investment = investment
          set_winner if inside_budget?
        end
      end
    end

    def vote_counting_winners
      investments.each_with_index.inject([]) do |memo, (inv, idx)|
        return memo if inv.ballot_lines_count.zero?
        if idx < 5 || memo.last.ballot_lines_count == inv.ballot_lines_count
          memo << inv
        else
          return memo
        end
      end
    end

    def investments
      heading.investments.selected.sort_by_ballots
    end

    def inside_budget?
      available_budget >= @current_investment.price
    end

    def available_budget
      total_budget - money_spent
    end

    def total_budget
      heading.price
    end

    def money_spent
      @money_spent ||= 0
    end

    def reset_winners
      investments.update_all(winner: false)
    end

    def set_winner
      @money_spent += @current_investment.price
      @current_investment.update!(winner: true, visible_to_valuators: true)
    end

    def winners
      investments.winners
    end
  end
end
