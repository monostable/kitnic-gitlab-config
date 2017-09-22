class AutocompleteController < ApplicationController
  AWARD_EMOJI_MAX = 100

  skip_before_action :authenticate_user!, only: [:users, :award_emojis]
  before_action :load_project, only: [:users]
  before_action :find_users, only: [:users]

  def users
    @users ||= User.none
    @users = @users.active
    @users = @users.reorder(:name)
    @users = @users.search(params[:search]) if params[:search].present?
    @users = @users.where.not(id: params[:skip_users]) if params[:skip_users].present?
    @users = @users.page(params[:page]).per(params[:per_page])

    if params[:todo_filter].present? && current_user
      @users = @users.todo_authors(current_user.id, params[:todo_state_filter])
    end

    if params[:search].blank?
      # Include current user if available to filter by "Me"
      if params[:current_user].present? && current_user
        @users = [current_user, *@users].uniq
      end

      if params[:author_id].present? && current_user
        author = User.find_by_id(params[:author_id])
        @users = [author, *@users].uniq if author
      end
    end

    render json: @users, only: [:name, :username, :id], methods: [:avatar_url]
  end

  def user
    @user = User.find(params[:id])
    render json: @user, only: [:name, :username, :id], methods: [:avatar_url]
  end

  def projects
    project = Project.find_by_id(params[:project_id])
    projects = projects_finder.execute(project, search: params[:search], offset_id: params[:offset_id])

    render json: projects.to_json(only: [:id, :name_with_namespace], methods: :name_with_namespace)
  end

  def award_emojis
    emoji_with_count = AwardEmoji
      .limit(AWARD_EMOJI_MAX)
      .where(user: current_user)
      .group(:name)
      .order('count_all DESC, name ASC')
      .count

    # Transform from hash to array to guarantee json order
    # e.g. { 'thumbsup' => 2, 'thumbsdown' = 1 }
    #   => [{ name: 'thumbsup' }, { name: 'thumbsdown' }]
    render json: emoji_with_count.map { |k, v| { name: k } }
  end

  private

  def find_users
    @users =
      if @project
        user_ids = @project.team.users.pluck(:id)

        if params[:author_id].present?
          user_ids << params[:author_id]
        end

        User.where(id: user_ids)
      elsif params[:group_id].present?
        group = Group.find(params[:group_id])
        return render_404 unless can?(current_user, :read_group, group)

        group.users
      elsif current_user
        User.all
      else
        User.none
      end
  end

  def load_project
    @project ||= begin
      if params[:project_id].present?
        project = Project.find(params[:project_id])
        return render_404 unless can?(current_user, :read_project, project)
        project
      end
    end
  end

  def projects_finder
    MoveToProjectFinder.new(current_user)
  end
end
