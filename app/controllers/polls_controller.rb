class PollsController < ApplicationController
  include PollsHelper

  before_action :load_poll, except: [:index]
  before_action :load_active_poll, only: :index

  load_and_authorize_resource

  has_filters %w[current expired]
  has_orders %w[newest oldest], only: :show

  ::Poll::Answer # trigger autoload

  def index
    @polls = Kaminari.paginate_array(
      @polls.created_by_admin.not_budget.send(@current_filter).includes(:geozones).order(:ends_at, :starts_at)
    ).page(params[:page])
  end

  def show
    @questions = @poll.questions.for_render.sort_for_list
    @token = poll_voter_token(@poll, current_user)
    @poll_questions_answers = Poll::Question::Answer.where(
      question: @poll.questions
    ).where.not(description: "").order(:given_order)

    @answers_by_question_id = ::Poll::Answer.answers_by_question_id(
      @poll.question_ids, current_user&.id
    )

    @commentable = @poll
    @comment_tree = CommentTree.new(@commentable, params[:page], @current_order)
  end

  def stats
    @stats = Poll::Stats.new(@poll)
    respond_to do |format|
      format.html
      format.csv do
        send_data Poll::Voters::Exporter.new(@poll).to_csv,
          filename: "participacao-#{@poll.filename}.csv"
      end
    end
  end

  def results
    respond_to do |format|
      format.html
      format.csv do
        send_data Poll::Question::Answer::Exporter.new(@poll.questions).to_csv,
          filename: "votacao-#{@poll.filename}.csv"
      end
    end
  end

  private

    def load_poll
      @poll = Poll.find_by_slug_or_id!(params[:id])
    end

    def load_active_poll
      @active_poll = ActivePoll.first
    end
end
