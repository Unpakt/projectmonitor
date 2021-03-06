class StatusController < ApplicationController
  def create
    project = Project.find_by_guid(params.delete(:project_id))
    payload = project.webhook_payload
    payload.status_content = params
    PayloadProcessor.new(project, payload).process
    head :ok
  end
end
