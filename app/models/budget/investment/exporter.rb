class Budget::Investment::Exporter
  require "csv"

  def initialize(investments)
    @investments = investments
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << headers
      @investments.each { |investment| csv << csv_values(investment) }
    end
  end

  def proposals_list_csv
    CSV.generate(headers: true) do |csv|
      csv << proposals_list_headers
      @investments.each do |investment|
        csv << proposals_list_csv_values(investment)
      end
    end
  end

  private

    PROPOSALS_COLUMNS = %w(id title description categories subprefecture prioritization votes balloting_result feasibility commitment unfeasibility_explanation).freeze

    FEASIBILITY_COLUMNS = %w(department budgetary_actions sei_number technical technical_description legal legal_description budgetary budgetary_description).freeze

    def proposals_list_headers
      headers = PROPOSALS_COLUMNS.map { |column| header_translation(column) }

      (1..5).each do |counter|
        FEASIBILITY_COLUMNS.each do |column|
          headers << "#{header_translation(column)} (#{counter})"
        end
      end

      headers
    end

    def proposals_list_csv_values(investment)
      row = [
        investment.id.to_s,
        investment.title,
        sanitize_description(investment.description),
        investment.tag_list.join(', '),
        investment.heading_name,
        prioritized_or_not(investment.selected?),
        investment.ballot_lines_count,
        elected_or_not(investment.winner?),
        feasibility_translation(investment.feasibility),
        sanitize_description(investment.commitment),
        sanitize_description(investment.unfeasibility_explanation)
      ]

      investment.feasibility_analyses.each do |analysis|
        feasibility_row = [
          analysis.department_name,
          analysis.budgetary_actions,
          analysis.sei_number,
          feasibility_translation(analysis.technical),
          sanitize_description(analysis.technical_description),
          feasibility_translation(analysis.legal),
          sanitize_description(analysis.legal_description),
          feasibility_translation(analysis.budgetary),
          sanitize_description(analysis.budgetary_description)
        ]
        row += feasibility_row
      end

      row
    end

    def headers
      [
        I18n.t("admin.budget_investments.index.list.id"),
        I18n.t("admin.budget_investments.index.list.title"),
        I18n.t("admin.budget_investments.index.list.supports"),
        I18n.t("admin.budget_investments.index.list.admin"),
        I18n.t("admin.budget_investments.index.list.valuator"),
        I18n.t("admin.budget_investments.index.list.valuation_group"),
        I18n.t("admin.budget_investments.index.list.geozone"),
        I18n.t("admin.budget_investments.index.list.feasibility"),
        I18n.t("admin.budget_investments.index.list.valuation_finished"),
        I18n.t("admin.budget_investments.index.list.selected"),
        I18n.t("admin.budget_investments.index.list.visible_to_valuators"),
        I18n.t("admin.budget_investments.index.list.author_username")
      ]
    end

    def csv_values(investment)
      [
        investment.id.to_s,
        investment.title,
        investment.total_votes.to_s,
        admin(investment),
        investment.assigned_valuators || "-",
        investment.assigned_valuation_groups || "-",
        investment.heading.name,
        price(investment),
        yes_or_no(investment.valuation_finished?),
        yes_or_no(investment.selected?),
        yes_or_no(investment.visible_to_valuators?),
        investment.author.username
      ]
    end

    def admin(investment)
      if investment.administrator.present?
        investment.administrator.name
      else
        I18n.t("admin.budget_investments.index.no_admin_assigned")
      end
    end

    def price(investment)
      price_string = "admin.budget_investments.index.feasibility.#{investment.feasibility}"
      if investment.feasible?
        "#{I18n.t(price_string)} (#{investment.formatted_price})"
      else
        I18n.t(price_string)
      end
    end

    def yes_or_no(condition)
      condition ? I18n.t("shared.yes") : I18n.t("shared.no")
    end

    def prioritized_or_not(condition)
      if condition
        investment_translation(:prioritized)
      else
        investment_translation(:not_prioritized)
      end
    end

    def elected_or_not(condition)
      if condition
        investment_translation(:elected)
      else
        investment_translation(:not_elected)
      end
    end

    def investment_translation(key)
      I18n.t(key, scope: "budgets.investments.investment")
    end

    def feasibility_translation(key)
      I18n.t(key, scope: "shared")
    end

    def header_translation(key)
      I18n.t(key, scope: 'budgets.show.spreadsheet')
    end

    def sanitize_description(description)
      Nokogiri::HTML.parse(description).text.squish
    end
end
