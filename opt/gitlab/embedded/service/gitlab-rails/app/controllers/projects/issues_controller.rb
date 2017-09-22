class Projects::IssuesController < Projects::ApplicationController
  include RendersNotes
  include ToggleSubscriptionAction
  include IssuableActions
  include ToggleAwardEmoji
  include IssuableCollections
  include SpammableActions

  prepend_before_action :authenticate_user!, only: [:new]

  before_action :check_issues_available!
  before_action :issue, except: [:index, :new, :create, :bulk_update]
  before_action :set_issues_index, only: [:index]

  # Allow write(create) issue
  before_action :authorize_create_issue!, only: [:new, :create]

  # Allow modify issue
  before_action :authorize_update_issue!, only: [:edit, :update, :move]

  # Allow create a new branch and empty WIP merge request from current issue
  before_action :authorize_create_merge_request!, only: [:create_merge_request]

  respond_to :html

  def index
    if params[:assignee_id].present?
      assignee = User.find_by_id(params[:assignee_id])
      @users.push(assignee) if assignee
    end

    if params[:author_id].present?
      author = User.find_by_id(params[:author_id])
      @users.push(author) if author
    end

    respond_to do |format|
      format.html
      format.atom { render layout: 'xml.atom' }
      format.json do
        render json: {
          html: view_to_html_string("projects/issues/_issues"),
          labels: @labels.as_json(methods: :text_color)
        }
      end
    end
  end

  def new
    params[:issue] ||= ActionController::Parameters.new(
      assignee_ids: ""
    )
    build_params = issue_params.merge(
      merge_request_to_resolve_discussions_of: params[:merge_request_to_resolve_discussions_of],
      discussion_to_resolve: params[:discussion_to_resolve]
    )
    service = Issues::BuildService.new(project, current_user, build_params)

    @issue = @noteable = service.execute
    @merge_request_to_resolve_discussions_of = service.merge_request_to_resolve_discussions_of
    @discussion_to_resolve = service.discussions_to_resolve.first if params[:discussion_to_resolve]

    respond_with(@issue)
  end

  def edit
    respond_with(@issue)
  end

  def show
    @noteable = @issue
    @note     = @project.notes.new(noteable: @issue)

    respond_to do |format|
      format.html
      format.json do
        render json: serializer.represent(@issue)
      end
    end
  end

  def discussions
    notes = @issue.notes
      .inc_relations_for_view
      .includes(:noteable)
      .fresh

    notes = prepare_notes_for_rendering(notes)
    notes = notes.reject { |n| n.cross_reference_not_visible_for?(current_user) }

    discussions = Discussion.build_collection(notes, @issue)

    render json: DiscussionSerializer.new(project: @project, noteable: @issue, current_user: current_user).represent(discussions)
  end

  def create
    create_params = issue_params.merge(spammable_params).merge(
      merge_request_to_resolve_discussions_of: params[:merge_request_to_resolve_discussions_of],
      discussion_to_resolve: params[:discussion_to_resolve]
    )

    service = Issues::CreateService.new(project, current_user, create_params)
    @issue = service.execute

    if service.discussions_to_resolve.count(&:resolved?) > 0
      flash[:notice] = if service.discussion_to_resolve_id
                         "Resolved 1 discussion."
                       else
                         "Resolved all discussions."
                       end
    end

    respond_to do |format|
      format.html do
        recaptcha_check_with_fallback { render :new }
      end
      format.js do
        @link = @issue.attachment.url.to_js
      end
    end
  end

  def update
    update_params = issue_params.merge(spammable_params)

    @issue = Issues::UpdateService.new(project, current_user, update_params).execute(issue)

    respond_to do |format|
      format.html do
        recaptcha_check_with_fallback { render :edit }
      end

      format.json do
        render_issue_json
      end
    end

  rescue ActiveRecord::StaleObjectError
    render_conflict_response
  end

  def move
    params.require(:move_to_project_id)

    if params[:move_to_project_id].to_i > 0
      new_project = Project.find(params[:move_to_project_id])
      return render_404 unless issue.can_move?(current_user, new_project)

      @issue = Issues::UpdateService.new(project, current_user, target_project: new_project).execute(issue)
    end

    respond_to do |format|
      format.json do
        render_issue_json
      end
    end

  rescue ActiveRecord::StaleObjectError
    render_conflict_response
  end

  def referenced_merge_requests
    @merge_requests = @issue.referenced_merge_requests(current_user)
    @closed_by_merge_requests = @issue.closed_by_merge_requests(current_user)

    respond_to do |format|
      format.json do
        render json: {
          html: view_to_html_string('projects/issues/_merge_requests')
        }
      end
    end
  end

  def related_branches
    @related_branches = @issue.related_branches(current_user)

    respond_to do |format|
      format.json do
        render json: {
          html: view_to_html_string('projects/issues/_related_branches')
        }
      end
    end
  end

  def can_create_branch
    can_create = current_user &&
      can?(current_user, :push_code, @project) &&
      @issue.can_be_worked_on?(current_user)

    respond_to do |format|
      format.json do
        render json: { can_create_branch: can_create, has_related_branch: @issue.has_related_branch? }
      end
    end
  end

  def realtime_changes
    Gitlab::PollingInterval.set_header(response, interval: 3_000)

    response = {
      title: view_context.markdown_field(@issue, :title),
      title_text: @issue.title,
      description: view_context.markdown_field(@issue, :description),
      description_text: @issue.description,
      task_status: @issue.task_status
    }

    if @issue.edited?
      response[:updated_at] = @issue.updated_at
      response[:updated_by_name] = @issue.last_edited_by.name
      response[:updated_by_path] = user_path(@issue.last_edited_by)
    end

    render json: response
  end

  def create_merge_request
    result = ::MergeRequests::CreateFromIssueService.new(project, current_user, issue_iid: issue.iid).execute

    if result[:status] == :success
      render json: MergeRequestCreateSerializer.new.represent(result[:merge_request])
    else
      render json: result[:messsage], status: :unprocessable_entity
    end
  end

  protected

  def issue
    return @issue if defined?(@issue)
    # The Sortable default scope causes performance issues when used with find_by
    @noteable = @issue ||= @project.issues.where(iid: params[:id]).reorder(nil).take!

    return render_404 unless can?(current_user, :read_issue, @issue)

    @issue
  end
  alias_method :subscribable_resource, :issue
  alias_method :issuable, :issue
  alias_method :awardable, :issue
  alias_method :spammable, :issue

  def spammable_path
    project_issue_path(@project, @issue)
  end

  def authorize_update_issue!
    render_404 unless can?(current_user, :update_issue, @issue)
  end

  def authorize_admin_issues!
    render_404 unless can?(current_user, :admin_issue, @project)
  end

  def authorize_create_merge_request!
    render_404 unless can?(current_user, :push_code, @project) && @issue.can_be_worked_on?(current_user)
  end

  def check_issues_available!
    return render_404 unless @project.feature_available?(:issues, current_user)
  end

  def render_issue_json
    if @issue.valid?
      render json: serializer.represent(@issue)
    else
      render json: { errors: @issue.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def issue_params
    params.require(:issue).permit(*issue_params_attributes)
  end

  def issue_params_attributes
    %i[
      title
      assignee_id
      position
      description
      confidential
      milestone_id
      due_date
      state_event
      task_num
      lock_version
    ] + [{ label_ids: [], assignee_ids: [] }]
  end

  def authenticate_user!
    return if current_user

    notice = "Please sign in to create the new issue."

    if request.get? && !request.xhr?
      store_location_for :user, request.fullpath
    end

    redirect_to new_user_session_path, notice: notice
  end

  def serializer
    IssueSerializer.new(current_user: current_user, project: issue.project)
  end
end
