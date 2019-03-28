Sequel.migration do
  change do
    create_table(:events) do
      primary_key :id
      String :reference_class, :text=>true
      Integer :reference_id
      String :data, :text=>true
      String :error_class, :text=>true
      String :error_message, :text=>true
      String :severity, :default=>"error", :text=>true
      String :worker, :text=>true
      String :backtrace, :text=>true
      String :backtrace_hash, :text=>true
      String :request, :text=>true
      DateTime :created_at
      DateTime :updated_at
      Integer :counter, :default=>1
    end
    
    create_table(:schema_info) do
      Integer :version, :default=>0, :null=>false
    end
  end
end
