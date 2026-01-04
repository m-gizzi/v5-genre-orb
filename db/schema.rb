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

ActiveRecord::Schema[8.1].define(version: 2026_01_04_051552) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "artists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.string "spotify_id", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_artists_on_name"
    t.index ["spotify_id"], name: "index_artists_on_spotify_id", unique: true
  end

  create_table "playlist_sync_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "playlist_id", null: false
    t.bigint "playlist_sync_run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["playlist_id"], name: "index_playlist_sync_items_on_playlist_id"
    t.index ["playlist_sync_run_id", "playlist_id"], name: "index_sync_items_on_sync_run_and_playlist_unique", unique: true
    t.index ["playlist_sync_run_id"], name: "index_playlist_sync_items_on_playlist_sync_run_id"
  end

  create_table "playlist_sync_runs", force: :cascade do |t|
    t.integer "batches_completed", default: 0
    t.integer "batches_total", default: 0
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "playlists_processed", default: 0
    t.datetime "started_at"
    t.integer "status", null: false
    t.integer "total_playlists_expected", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_playlist_sync_runs_on_created_at"
    t.index ["status"], name: "index_playlist_sync_runs_on_status"
    t.index ["user_id", "status"], name: "index_playlist_sync_runs_on_user_id_and_status"
    t.index ["user_id"], name: "index_playlist_sync_runs_on_user_id"
    t.index ["user_id"], name: "index_sync_runs_on_user_active_unique", unique: true, where: "(status = ANY (ARRAY[0, 1, 2, 3]))"
  end

  create_table "playlist_tracks", force: :cascade do |t|
    t.datetime "added_at"
    t.string "added_by_spotify_id"
    t.datetime "created_at", null: false
    t.bigint "playlist_id", null: false
    t.bigint "track_id", null: false
    t.datetime "updated_at", null: false
    t.index ["playlist_id", "track_id"], name: "index_playlist_tracks_on_playlist_id_and_track_id", unique: true
    t.index ["playlist_id"], name: "index_playlist_tracks_on_playlist_id"
    t.index ["track_id"], name: "index_playlist_tracks_on_track_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "last_track_sync_snapshot_id"
    t.datetime "last_track_synced_at"
    t.string "name", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.string "snapshot_id"
    t.string "spotify_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["last_track_sync_snapshot_id"], name: "index_playlists_on_last_track_sync_snapshot_id"
    t.index ["snapshot_id"], name: "index_playlists_on_snapshot_id"
    t.index ["spotify_id"], name: "index_playlists_on_spotify_id", unique: true
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "rate_limit_cooldowns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "endpoint", null: false
    t.datetime "expires_at", null: false
    t.integer "retry_after_seconds", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_cooldowns_on_endpoint_unique", unique: true
    t.index ["expires_at"], name: "index_rate_limit_cooldowns_on_expires_at"
  end

  create_table "track_artists", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.datetime "created_at", null: false
    t.bigint "track_id", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_id"], name: "index_track_artists_on_artist_id"
    t.index ["track_id", "artist_id"], name: "index_track_artists_on_track_id_and_artist_id", unique: true
    t.index ["track_id"], name: "index_track_artists_on_track_id"
  end

  create_table "track_sync_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "track_id", null: false
    t.bigint "track_sync_run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["track_id"], name: "index_track_sync_items_on_track_id"
    t.index ["track_sync_run_id", "track_id"], name: "index_track_sync_items_on_sync_run_and_track_unique", unique: true
    t.index ["track_sync_run_id"], name: "index_track_sync_items_on_track_sync_run_id"
  end

  create_table "track_sync_runs", force: :cascade do |t|
    t.integer "artists_processed", default: 0
    t.integer "batches_completed", default: 0
    t.integer "batches_total", default: 0
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "playlist_id", null: false
    t.datetime "started_at"
    t.integer "status", null: false
    t.integer "tracks_processed", default: 0
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_track_sync_runs_on_created_at"
    t.index ["playlist_id", "status"], name: "index_track_sync_runs_on_playlist_id_and_status"
    t.index ["playlist_id"], name: "index_track_sync_runs_on_playlist_active_uniqu", unique: true, where: "(status = ANY (ARRAY[0, 1, 2, 3]))"
    t.index ["playlist_id"], name: "index_track_sync_runs_on_playlist_id"
    t.index ["status"], name: "index_track_sync_runs_on_status"
  end

  create_table "tracks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "disc_number"
    t.integer "duration_ms"
    t.boolean "explicit", default: false, null: false
    t.boolean "is_local", default: false, null: false
    t.string "isrc"
    t.string "name", null: false
    t.integer "popularity"
    t.string "preview_url"
    t.jsonb "raw_data", default: {}, null: false
    t.string "spotify_id", null: false
    t.integer "track_number"
    t.datetime "updated_at", null: false
    t.index ["spotify_id"], name: "index_tracks_on_spotify_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.text "access_token_ciphertext"
    t.datetime "created_at", null: false
    t.text "refresh_token_ciphertext"
    t.string "spotify_display_name"
    t.string "spotify_email"
    t.string "spotify_id", null: false
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.index ["spotify_id"], name: "index_users_on_spotify_id", unique: true
  end

  add_foreign_key "playlist_sync_items", "playlist_sync_runs"
  add_foreign_key "playlist_sync_items", "playlists"
  add_foreign_key "playlist_sync_runs", "users"
  add_foreign_key "playlist_tracks", "playlists"
  add_foreign_key "playlist_tracks", "tracks"
  add_foreign_key "playlists", "users"
  add_foreign_key "track_artists", "artists"
  add_foreign_key "track_artists", "tracks"
  add_foreign_key "track_sync_items", "track_sync_runs"
  add_foreign_key "track_sync_items", "tracks"
  add_foreign_key "track_sync_runs", "playlists"
end
