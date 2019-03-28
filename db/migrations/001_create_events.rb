Sequel.migration do
  change do
    create_table "events", force: :cascade do
      primary_key :id

      String   "reference_class"
      Integer  "reference_id"
      String   "data", text: true
      String   "error_class"
      String   "error_message"
      String   "severity",        default: "error"
      String   "worker"
      String   "backtrace", text: true
      String   "backtrace_hash"
      String   "request", text: true

      DateTime "created_at"
      DateTime "updated_at"

      Integer  "counter",         default: 1
    end
  end
end
