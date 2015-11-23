class UsersController < ApplicationController

  skip_before_action :authenticate, only: [:create,
    :gh_authorize, :gh_authenticate,
    :is_registered?,
    :new,
    :sign_in, :sign_in!
  ]

  def orphans
    @users = User.all.select{|u| u.groups.count < 1}
    render :index
  end

  def show
    if params[:user]
      if User.exists?(username: params[:user])
        @user = User.find_by(username: params[:user])
      else
        raise "User #{params[:user]} not found!"
      end
    elsif signed_in?
      @user = current_user
    else
      redirect_to action: :sign_out
    end
    @is_current_user = (@user.id == current_user.id)
    @is_admin_of_anything = @user.is_admin_of_anything?
    @is_adminned_by_current_user = (@user.groups_adminned_by(current_user).count > 0)
    @is_editable = @is_current_user && !@user.github_id
    @memberships = @user.memberships.sort_by{|a| a.group.path_string}
    if (@is_current_user || @is_adminned_by_current_user)
      @attendances = @user.attendances.sort_by{|a| a.event.date}
      @submissions = @user.submissions.where.not(status: nil).sort_by{|a| a.assignment.due_date}
      @submission_notes = @submissions.select(&:grader_notes)
    end
    if !@is_current_user && @is_adminned_by_current_user
      @observations = @user.records_accessible_by(current_user, "observations").sort_by(&:created_at)
      @common_groups = (@user.groups & current_user.adminned_groups).collect{|g| [g.path_string, g.id]}
    end
    if @is_current_user && @is_admin_of_anything
      @due_submissions = @user.get_due("submissions")
      @due_attendances = @user.get_due("attendances")
    end
  end

  def update
    if params[:form_user][:password_confirmation] != params[:form_user][:password]
      raise "Your passwords don't match!"
    else
      @user = current_user
      if @user && @user.update!(user_params)
        set_current_user(@user)
        flash[:notice] = "Account updated!"
      else
        flash[:notice] = "Since you're using Github, you'll need to make all your changes there."
      end
    end
    redirect_to action: :show
  end

  def destroy
    current_user.destroy
    reset_session
    redirect_to root_path
  end

  def new
    if current_user
      redirect_to action: :show
    end
    @user = User.new
    @is_editable = true
  end

  def create
    @user = User.new(user_params)
    if params[:password_confirmation] != params[:password]
      raise "Your passwords don't match!"
    elsif @user.save!
      flash[:notice] = "You've signed up!"
      set_current_user @user
      redirect_to action: :show
    else
      raise "Your account couldn't be created. Did you enter a unique username and password?"
    end
  end

  def sign_in
    if current_user
      redirect_to action: :show
    end
  end

  def is_registered?
    render json: User.exists?(username: params[:github_username])
  end

  def sign_in!
    if signed_in?
      @user = current_user
    elsif params[:username]
      if !User.exists?(username: params[:username])
        raise "That user doesn't seem to exist!"
      else
        @user = User.find_by(username: params[:username])
        if @user.github_id
          return gh_authorize
        elsif !@user.password_ok?(params[:password])
          raise "Something went wrong! Is your password right?"
        end
      end
    end
    set_current_user @user
    flash[:notice] = "You're signed in, #{@user.username}!"
    redirect_to action: :show
  end

  def sign_out
    reset_session
    message = "You're signed out!"
    flash[:notice] = message
    redirect_to root_path
  end

  def gh_authorize
    redirect_to Github.new(ENV).oauth_link
  end

  def gh_authenticate
    if(!params[:code])
      redirect_to action: :gh_authorize
    end
    github = Github.new(ENV)
    session[:access_token] = github.get_access_token(params[:code])
    gh_user_info = github.user_info
    @gh_user = User.find_by(github_id: gh_user_info[:github_id])
    if @gh_user
      if signed_in? && @gh_user.id != current_user.id
        raise "The username #{gh_user_info[:username]} is taken!"
      end
    else
      @gh_user = User.new
    end
    if @gh_user.update!(gh_user_info)
      set_current_user @gh_user
      redirect_to action: :sign_in
    end
  end

  def gh_refresh
    gh_user_info = Github.new(ENV).get_user_by_id(params[:github_id])
    @user = User.find_by(github_id: gh_user_info[:github_id])
    @user.update!(gh_user_info)
    flash[:notice] = "Github info updated!"
    redirect_to user_path(@user)
  end

  def gh_refresh_all
    User.all.each do |user|
      puts "Refreshing #{user.id}, #{user.username}..."
      if !user.github_id
        puts "Skipping..."
        next
      end
      gh_user_info = Github.new(ENV).get_user_by_id(user.github_id)
      @user = User.find_by(github_id: gh_user_info[:github_id])
      @user.update!(gh_user_info) if @user
    end
    redirect_to action: :index
  end

  private
  def user_params
    params.require(:form_user).permit(:password, :username, :name, :email, :image_url)
  end

end
