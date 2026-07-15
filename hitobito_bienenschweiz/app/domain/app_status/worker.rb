# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class AppStatus::Worker < AppStatus
  def details
    {worker_running: worker_running?}
  end

  def code
    worker_running? ? AppStatus::OK : AppStatus::SERVICE_UNAVAILABLE
  end

  private

  def worker_running?
    return true unless Delayed::Heartbeat.configuration.enabled?

    timeout = Delayed::Heartbeat.configuration.heartbeat_timeout_seconds
    Delayed::Heartbeat::Worker.where(last_heartbeat_at: (Time.now.utc - timeout)..).exists?
  end
end
