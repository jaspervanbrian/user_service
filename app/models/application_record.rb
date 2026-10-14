class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Multi-DB Primary / Replica Switching (PostgreSQL / SQLite):
  # Reads automatically query the replica; writes query the primary.
  # connects_to database: { writing: :primary, reading: :primary_replica }
end
