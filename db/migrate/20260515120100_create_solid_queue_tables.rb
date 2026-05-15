class CreateSolidQueueTables < ActiveRecord::Migration[8.1]
  def change
    create_solid_queue_jobs
    create_solid_queue_blocked_executions
    create_solid_queue_claimed_executions
    create_solid_queue_failed_executions
    create_solid_queue_pauses
    create_solid_queue_processes
    create_solid_queue_ready_executions
    create_solid_queue_recurring_executions
    create_solid_queue_recurring_tasks
    create_solid_queue_scheduled_executions
    create_solid_queue_semaphores
    add_solid_queue_foreign_keys
  end

  private

  def create_solid_queue_jobs
    return if table_exists?(:solid_queue_jobs)

    create_table :solid_queue_jobs do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, default: 0, null: false
      t.string :active_job_id
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :concurrency_key
      t.timestamps

      t.index :active_job_id
      t.index :class_name
      t.index :finished_at
      t.index [:queue_name, :finished_at], name: "index_solid_queue_jobs_for_filtering"
      t.index [:scheduled_at, :finished_at], name: "index_solid_queue_jobs_for_alerting"
    end
  end

  def create_solid_queue_blocked_executions
    return if table_exists?(:solid_queue_blocked_executions)

    create_table :solid_queue_blocked_executions do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.string :concurrency_key, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false

      t.index [:concurrency_key, :priority, :job_id], name: "index_solid_queue_blocked_executions_for_release"
      t.index [:expires_at, :concurrency_key], name: "index_solid_queue_blocked_executions_for_maintenance"
      t.index :job_id, unique: true
    end
  end

  def create_solid_queue_claimed_executions
    return if table_exists?(:solid_queue_claimed_executions)

    create_table :solid_queue_claimed_executions do |t|
      t.bigint :job_id, null: false
      t.bigint :process_id
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
      t.index [:process_id, :job_id]
    end
  end

  def create_solid_queue_failed_executions
    return if table_exists?(:solid_queue_failed_executions)

    create_table :solid_queue_failed_executions do |t|
      t.bigint :job_id, null: false
      t.text :error
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
    end
  end

  def create_solid_queue_pauses
    return if table_exists?(:solid_queue_pauses)

    create_table :solid_queue_pauses do |t|
      t.string :queue_name, null: false
      t.datetime :created_at, null: false

      t.index :queue_name, unique: true
    end
  end

  def create_solid_queue_processes
    return if table_exists?(:solid_queue_processes)

    create_table :solid_queue_processes do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.datetime :created_at, null: false
      t.string :name, null: false

      t.index :last_heartbeat_at
      t.index [:name, :supervisor_id], unique: true
      t.index :supervisor_id
    end
  end

  def create_solid_queue_ready_executions
    return if table_exists?(:solid_queue_ready_executions)

    create_table :solid_queue_ready_executions do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
      t.index [:priority, :job_id], name: "index_solid_queue_poll_all"
      t.index [:queue_name, :priority, :job_id], name: "index_solid_queue_poll_by_queue"
    end
  end

  def create_solid_queue_recurring_executions
    return if table_exists?(:solid_queue_recurring_executions)

    create_table :solid_queue_recurring_executions do |t|
      t.bigint :job_id, null: false
      t.string :task_key, null: false
      t.datetime :run_at, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
      t.index [:task_key, :run_at], unique: true
    end
  end

  def create_solid_queue_recurring_tasks
    return if table_exists?(:solid_queue_recurring_tasks)

    create_table :solid_queue_recurring_tasks do |t|
      t.string :key, null: false
      t.string :schedule, null: false
      t.string :command, limit: 2048
      t.string :class_name
      t.text :arguments
      t.string :queue_name
      t.integer :priority, default: 0
      t.boolean :static, default: true, null: false
      t.text :description
      t.timestamps

      t.index :key, unique: true
      t.index :static
    end
  end

  def create_solid_queue_scheduled_executions
    return if table_exists?(:solid_queue_scheduled_executions)

    create_table :solid_queue_scheduled_executions do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
      t.index [:scheduled_at, :priority, :job_id], name: "index_solid_queue_dispatch_all"
    end
  end

  def create_solid_queue_semaphores
    return if table_exists?(:solid_queue_semaphores)

    create_table :solid_queue_semaphores do |t|
      t.string :key, null: false
      t.integer :value, default: 1, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :expires_at
      t.index [:key, :value]
      t.index :key, unique: true
    end
  end

  def add_solid_queue_foreign_keys
    [
      :solid_queue_blocked_executions,
      :solid_queue_claimed_executions,
      :solid_queue_failed_executions,
      :solid_queue_ready_executions,
      :solid_queue_recurring_executions,
      :solid_queue_scheduled_executions
    ].each do |table_name|
      next if foreign_key_exists?(table_name, :solid_queue_jobs, column: :job_id)

      add_foreign_key table_name, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    end
  end
end
