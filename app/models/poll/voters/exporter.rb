class Poll::Voters::Exporter
  require "csv"

  def initialize(poll)
    @poll = poll
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << VOTER_COLUMNS.map { |column| voter_translation(column) }

      @poll.voters.each do |voter|
        csv << csv_row(voter)
      end

      @poll.recounts.each do |recount|
        unidentified_voters_amount(recount).times do
          csv << [recount.id.to_s, voter_translation(recount.origin)]
        end
      end
    end
  end

  private

  VOTER_COLUMNS = %w(id origin gender ethnicity age city uf).freeze

  def csv_row(voter)
    [
      voter.id.to_s,
      voter_translation(voter.origin),
      gender_translation(voter),
      ethnicity_translation(voter),
      voter.age,
      voter.user&.city,
      voter.user&.uf
    ]
  end

  def voter_translation(key)
    I18n.t(key, scope: 'stats.polls.voters.spreadsheet')
  end

  def gender_translation(voter)
    if voter.gender.present?
      voter_translation("gender_options.#{voter.gender}")
    end
  end

  def ethnicity_translation(voter)
    if voter.ethnicity.present?
      voter_translation("ethnicity_options.#{voter.ethnicity}")
    end
  end

  def unidentified_voters_amount(recount)
    recount.total_amount - recount.voters.size
  end
end
