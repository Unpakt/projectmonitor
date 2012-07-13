class ProjectContentFetcher
  delegate :feed_url, :build_status_url, :auth_username, :auth_password, to: :project

  def initialize(project)
    self.project = project
  end

  def fetch
    status_content = fetch_status if project.feed_url
    # building_status_content = fetch_building_status if project.build_status_url
    # [status_content, building_status_content].compact
  end

  private

  def fetch_status
    content = UrlRetriever.retrieve_content_at(feed_url, auth_username, auth_password)
  rescue Net::HTTPError => e
    error = "HTTP Error retrieving status for project '##{project.id}': #{e.message}"
    project.statuses.create(:error => error) unless project.status.error == error
  end

  def fetch_building_status
    content = UrlRetriever.retrieve_content_at(build_status_url, auth_username, auth_password)
  rescue Net::HTTPError => e
    project.update_attribute(:building, false)
  end

  attr_accessor :project
end
