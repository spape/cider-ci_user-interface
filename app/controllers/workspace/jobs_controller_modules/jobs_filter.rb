module Workspace::JobsControllerModules::JobsFilter
  extend ActiveSupport::Concern

  def build_jobs_for_params
    filter_jobs_for_tree_id filter_jobs_for_tags filter_by_repository_names \
      filter_jobs_for_branch_name set_per_page build_jobs_initial_scope
  end

  def set_per_page(jobs)
    if params[:per_page].present?
      jobs.per(Integer(params[:per_page]))
    else
      jobs
    end
  end

  def build_jobs_initial_scope
    Job.reorder(created_at: :desc).page(params[:page]) \
      .select(:id, :created_at, :tree_id, :state, :name, :updated_at)
  end

  def filter_jobs_for_tree_id(jobs)
    if tree_id_filter
      jobs.where('jobs.tree_id ilike ?', "#{tree_id_filter}%")
    else
      jobs
    end
  end

  def filter_by_repository_names(jobs)
    unless repository_names_filter.empty?
      jobs.joins(commits: { branches: :repository }) \
        .distinct.where(repositories: { name: repository_names_filter })
    else
      jobs
    end
  end

  def filter_jobs_for_branch_name(jobs)
    unless branch_names_filter.empty?
      jobs.joins(commits: :branches) \
        .where(branches: { name: branch_names_filter })
    else
      jobs
    end
  end

  def filter_jobs_for_tags(jobs)
    if job_tags_filter.count > 0
      jobs.joins(:tags).where(tags: { tag: job_tags_filter })
    else
      jobs
    end
  end

end
