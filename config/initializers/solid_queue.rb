# Diagnostic for rails/solid_queue#585 / our issue #215.
#
# The worker's polling thread hangs forever inside claim_executions.
# statement_timeout: 10s didn't save it last time — either the setting isn't
# applying, or the query never reaches PG (dead TCP connection).
#
# This version:
# 1. Verifies connection settings on first poll (proves they're applied)
# 2. Logs poll/claim boundaries to pinpoint the hang
module SolidQueueWorkerDiagnostics
  def poll
    verify_connection_settings_once
    Rails.logger.error("[SolidQueue::Diag] poll enter pid=#{Process.pid}")
    result = super
    Rails.logger.error("[SolidQueue::Diag] poll exit pid=#{Process.pid} sleep=#{result}")
    result
  end

  def claim_executions
    Rails.logger.error("[SolidQueue::Diag] claim enter pid=#{Process.pid}")
    result = super
    Rails.logger.error("[SolidQueue::Diag] claim exit pid=#{Process.pid} claimed=#{result.size}")
    result
  end

  private

  def verify_connection_settings_once
    return if @connection_settings_verified
    @connection_settings_verified = true

    conn = SolidQueue::Record.connection
    return unless conn.adapter_name == "PostgreSQL"

    statement_timeout = conn.execute("SHOW statement_timeout; -- diag").first["statement_timeout"]
    lock_timeout = conn.execute("SHOW lock_timeout; -- diag").first["lock_timeout"]

    raw_conn = conn.raw_connection
    keepalives = raw_conn.conninfo_hash[:keepalives]
    tcp_user_timeout = raw_conn.conninfo_hash[:tcp_user_timeout]

    Rails.logger.error(
      "[SolidQueue::Diag] connection settings verified pid=#{Process.pid}: " \
      "statement_timeout=#{statement_timeout}, lock_timeout=#{lock_timeout}, " \
      "keepalives=#{keepalives}, tcp_user_timeout=#{tcp_user_timeout}"
    )
  rescue => e
    Rails.logger.error(
      "[SolidQueue::Diag] failed to verify connection settings pid=#{Process.pid}: #{e.message}"
    )
  end
end

Rails.application.config.after_initialize do
  SolidQueue::Worker.prepend(SolidQueueWorkerDiagnostics)
end
