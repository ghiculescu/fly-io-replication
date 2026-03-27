class QueueHeartbeatJob < ApplicationJob
  queue_as :default

  def perform
    heartbeat = QueueHeartbeat.first_or_initialize
    heartbeat.update!(last_beat_at: Time.current)
  end
end
