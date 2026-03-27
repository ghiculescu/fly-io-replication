class CreateQueueHeartbeats < ActiveRecord::Migration[8.0]
  def change
    create_table :queue_heartbeats do |t|
      t.datetime :last_beat_at, null: false
      t.timestamps
    end
  end
end
