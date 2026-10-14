# frozen_string_literal: true

# ==============================================================================
# Automatic Database Role Switching (Primary / Replica Read-Your-Own-Writes)
# ==============================================================================
# When running with a Primary (Writer) and Read Replicas (e.g., PostgreSQL streaming
# replication), GET requests read from the replica while POST/PATCH/DELETE write
# to the primary.
#
# To solve the "Read Your Own Writes" replication lag anomaly in stateless JWT APIs,
# we use `Auth::DatabaseResolverContext`, which tracks each user's last write
# timestamp in Redis / Rails.cache rather than cookie sessions.
#
# When last_write_timestamp is absent (or older than delay), queries default
# to the read replica (keeping >99% of read traffic off the primary).
#
# To enable:
# 1. Configure primary and replica in config/database.yml (e.g. for PostgreSQL)
# 2. Uncomment connects_to in app/models/application_record.rb
# 3. Uncomment the block below:
#
# Rails.application.configure do
#   config.active_record.database_selector = { delay: 2.seconds }
#   config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
#   config.active_record.database_resolver_context = Auth::DatabaseResolverContext
# end
