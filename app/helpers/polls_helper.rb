module PollsHelper
  def poll_select_options(include_all = nil)
    options = @polls.map do |poll|
      [poll.name, current_path_with_query_params(poll_id: poll.id)]
    end
    options << all_polls if include_all
    options_for_select(options, request.fullpath)
  end

  def all_polls
    [I18n.t("polls.all"), admin_questions_path]
  end

  def poll_dates(poll)
    if poll.starts_at.blank? || poll.ends_at.blank?
      I18n.t("polls.no_dates")
    else
      I18n.t("polls.dates", open_at: l(poll.starts_at.to_date), closed_at: l(poll.ends_at.to_date))
    end
  end

  def booth_name_with_location(booth)
    location = booth.location.blank? ? "" : " (#{booth.location})"
    booth.name + location
  end

  def poll_voter_token(poll, user)
    Poll::Voter.find_by(poll: poll, user: user, origin: "web")&.token || ""
  end

  def link_to_poll(text, poll)
    if can?(:results, poll)
      link_to text, results_poll_path(id: poll.id)
    elsif can?(:stats, poll)
      link_to text, stats_poll_path(id: poll.id)
    else
      link_to text, poll_path(id: poll.id)
    end
  end

  def results_menu?
    controller_name == "polls" && action_name == "results"
  end

  def stats_menu?
    controller_name == "polls" && action_name == "stats"
  end

  def info_menu?
    controller_name == "polls" && action_name == "show"
  end

  def show_polls_description?
    @active_poll.present? && @current_filter == "current"
  end

  def able_to_participate?(poll, question)
    can?(:answer, question) &&
    !poll.voted_in_booth?(current_user) &&
    (
      !poll.electoral_college_restricted? ||
      poll.belongs_to_electoral_college?(current_user, question.category)
    )
  end

  def poll_votes_counter(question)
    question.votes_per_question - question.user_answers_count(current_user)
  end

  def votes_counter_key(question)
    if question.user_answers_count(current_user) == 0
      "vote_limit"
    else
      "remaining_votes"
    end
  end

  def answer_border(index)
    return "" if index.even?
    index % 3 == 0 ? "" : "answer-info-border-right"
  end

  def poll_total_votes_count
    @poll.expired? ? @poll.answer_count : @poll.web_answers_count
  end

  def expired?
    @current_filter == "expired"
  end

  def question_answers_count(poll, question, answer)
    count = question.answers.votes_count(answer.title)
    return count unless poll.expired?
    count + question.partial_results.booth_votes_count(answer.title)
  end
end
