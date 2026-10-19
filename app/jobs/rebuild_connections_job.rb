class RebuildConnectionsJob < ApplicationJob
  def perform
    Connection.active.find_each { RebuildConnectionJob.perform_later(it) }
  end
end
