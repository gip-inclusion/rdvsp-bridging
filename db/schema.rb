# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_19_230000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "provider", default: "pipedrive", null: false
    t.string "name", null: false
    t.text "api_token", null: false
    t.string "provider_company_id"
    t.string "provider_company_domain"
    t.boolean "usager_details", default: false, null: false
    t.boolean "link_persons", default: false, null: false
    t.string "alert_email"
    t.string "webhook_token", null: false
    t.string "provider_webhook_id"
    t.string "rdv_activity_type_key"
    t.datetime "refresh_cursor"
    t.datetime "refreshed_at"
    t.datetime "failing_since"
    t.text "last_error"
    t.datetime "alerted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "access_token"
    t.datetime "access_token_expires_at"
    t.index ["provider", "provider_company_id"], name: "index_accounts_on_provider_and_provider_company_id", unique: true
    t.index ["webhook_token"], name: "index_accounts_on_webhook_token", unique: true
  end

  create_table "busy_block_changes", force: :cascade do |t|
    t.bigint "connection_id", null: false
    t.datetime "created_at", null: false
    t.index ["connection_id"], name: "index_busy_block_changes_on_connection_id"
  end

  create_table "busy_blocks", force: :cascade do |t|
    t.bigint "connection_id", null: false
    t.string "provider_object_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.datetime "deleted_at"
    t.bigint "seq", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["connection_id", "provider_object_id"], name: "index_busy_blocks_on_connection_id_and_provider_object_id", unique: true
    t.index ["connection_id", "seq"], name: "index_busy_blocks_on_connection_id_and_seq"
  end

  create_table "connections", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "provider_user_id", null: false
    t.string "provider_user_name"
    t.string "agent_email"
    t.string "public_id", null: false
    t.string "username", null: false
    t.string "password_digest", null: false
    t.boolean "include_all_day", default: false, null: false
    t.integer "sync_generation", default: 1, null: false
    t.bigint "pruned_through_seq", default: 0, null: false
    t.datetime "rebuilt_at"
    t.datetime "last_seen_at"
    t.datetime "disabled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider_user_id"], name: "index_connections_on_account_id_and_provider_user_id", unique: true
    t.index ["account_id"], name: "index_connections_on_account_id"
    t.index ["public_id"], name: "index_connections_on_public_id", unique: true
    t.index ["username"], name: "index_connections_on_username", unique: true
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.index ["created_at", "id"], name: "index_good_job_batches_on_created_at_and_id", order: :desc
    t.index ["finished_at"], name: "index_good_job_batches_on_finished_at", where: "(finished_at IS NOT NULL)"
  end

  create_table "good_job_concurrency_claims", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "job_id", null: false
    t.uuid "locked_by_id"
    t.integer "state", limit: 2, null: false
    t.text "key", null: false
    t.index ["job_id"], name: "index_good_job_concurrency_claims_on_job_id"
    t.index ["key", "job_id"], name: "index_good_job_concurrency_claims_on_key_and_job_id", unique: true
    t.index ["key", "state", "created_at"], name: "index_good_job_concurrency_claims_for_promotion"
    t.index ["locked_by_id"], name: "index_good_job_concurrency_claims_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
    t.index ["scheduled_at"], name: "index_good_job_executions_on_scheduled_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.integer "lock_type", limit: 2
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id_unfinished", where: "((batch_callback_id IS NOT NULL) AND (finished_at IS NULL))"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id_unfinished", where: "((batch_id IS NOT NULL) AND (finished_at IS NULL))"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["created_at"], name: "index_good_jobs_on_created_at"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, order: { cron_at: "DESC NULLS LAST" }, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_on_discarded", order: :desc, where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["id"], name: "index_good_jobs_on_unfinished_or_errored", where: "((finished_at IS NULL) OR (error IS NOT NULL))"
    t.index ["job_class", "finished_at"], name: "index_good_jobs_on_discarded_job_class", where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_for_candidate_dequeue_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_on_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name", "priority", "created_at"], name: "index_good_jobs_dequeue_by_queue", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "priority", "scheduled_at"], name: "index_good_jobs_dequeue_by_queue_scheduled_at", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at", "id"], name: "index_good_jobs_on_queue_name_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name"], name: "index_good_jobs_on_queue_name"
    t.index ["scheduled_at", "queue_name"], name: "index_good_jobs_on_scheduled_at_and_queue_name"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "rdvs", force: :cascade do |t|
    t.bigint "connection_id", null: false
    t.string "href_name", null: false
    t.string "uid"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.text "payload"
    t.string "etag", null: false
    t.string "provider_object_id"
    t.string "provider_person_id"
    t.string "state", default: "pending", null: false
    t.datetime "cancelled_at"
    t.datetime "pushed_at"
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["connection_id", "href_name"], name: "index_rdvs_on_connection_id_and_href_name", unique: true
    t.index ["provider_object_id"], name: "index_rdvs_on_provider_object_id"
  end

  add_foreign_key "busy_block_changes", "connections", on_delete: :cascade
  add_foreign_key "busy_blocks", "connections"
  add_foreign_key "connections", "accounts"
  add_foreign_key "rdvs", "connections"
end
