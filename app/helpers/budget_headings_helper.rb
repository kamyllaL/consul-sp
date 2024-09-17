module BudgetHeadingsHelper
  def budget_heading_select_options(budget)
    budget.headings.sort_by_name.map do |heading|
      [heading.name, heading.id]
    end
  end

  def budget_heading_slug_options(budget)
    budget.headings.sort_by_name.map do |heading|
      [heading.name, heading.slug]
    end
  end

  def heading_link(assigned_heading = nil, budget = nil)
    return nil unless assigned_heading && budget

    heading_path = budget_investments_path(budget, heading_id: assigned_heading&.id)
    link_to(assigned_heading.name, heading_path)
  end

  def existing_heading(slug)
    @heading ||= @budget.headings.find_by_slug(slug)
  end
end
