# frozen_string_literal: true

# Idempotent seed script creating sample admin and member accounts.
# Run with `bin/rails db:seed`.
# All seeded users have the password: password123

puts "Seeding users..."

users_data = [
  # Admins
  {
    username: "AdaAdmin",
    first_name: "Ada",
    last_name: "Lovelace",
    email: "ada.admin@example.com",
    role: :admin,
    date_of_birth: Date.new(1990, 1, 15)
  },
  {
    username: "AlanAdmin",
    first_name: "Alan",
    last_name: "Turing",
    email: "alan.admin@example.com",
    role: :admin,
    date_of_birth: Date.new(1988, 6, 23)
  },

  # Members (with DOB)
  {
    username: "grace_h",
    first_name: "Grace",
    last_name: "Hopper",
    email: "grace.hopper@example.com",
    role: :member,
    date_of_birth: Date.new(1992, 12, 9)
  },
  {
    username: "LinusT",
    first_name: "Linus",
    last_name: "Torvalds",
    email: "linus@example.com",
    role: :member,
    date_of_birth: Date.new(1989, 12, 28)
  },
  {
    username: "margaret_h",
    first_name: "Margaret",
    last_name: "Hamilton",
    email: "margaret@example.com",
    role: :member,
    date_of_birth: Date.new(1986, 8, 17)
  },
  {
    username: "TimBL",
    first_name: "Tim",
    last_name: "Berners-Lee",
    email: "timbl@example.com",
    role: :member,
    date_of_birth: Date.new(1995, 6, 8)
  },
  {
    username: "katherine_j",
    first_name: "Katherine",
    last_name: "Johnson",
    email: "katherine@example.com",
    role: :member,
    date_of_birth: Date.new(1998, 8, 26)
  },
  {
    username: "DennisR",
    first_name: "Dennis",
    last_name: "Ritchie",
    email: "dennis@example.com",
    role: :member,
    date_of_birth: Date.new(1991, 9, 9)
  },
  {
    username: "barbara_l",
    first_name: "Barbara",
    last_name: "Liskov",
    email: "barbara@example.com",
    role: :member,
    date_of_birth: Date.new(1993, 11, 7)
  },
  {
    username: "ken_t",
    first_name: "Ken",
    last_name: "Thompson",
    email: "ken@example.com",
    role: :member,
    date_of_birth: Date.new(1993, 2, 4)
  },
  {
    username: "guido_vr",
    first_name: "Guido",
    last_name: "van Rossum",
    email: "guido@example.com",
    role: :member,
    date_of_birth: Date.new(1996, 1, 31)
  },
  {
    username: "radia_p",
    first_name: "Radia",
    last_name: "Perlman",
    email: "radia@example.com",
    role: :member,
    date_of_birth: Date.new(1991, 1, 1)
  },

  # Members (without DOB - testing optional date_of_birth)
  {
    username: "matz",
    first_name: "Yukihiro",
    last_name: "Matsumoto",
    email: "matz@example.com",
    role: :member,
    date_of_birth: nil
  },
  {
    username: "bjarne_s",
    first_name: "Bjarne",
    last_name: "Stroustrup",
    email: "bjarne@example.com",
    role: :member,
    date_of_birth: nil
  },
  {
    username: "james_g",
    first_name: "James",
    last_name: "Gosling",
    email: "james@example.com",
    role: :member,
    date_of_birth: nil
  },
  {
    username: "brendan_e",
    first_name: "Brendan",
    last_name: "Eich",
    email: "brendan@example.com",
    role: :member,
    date_of_birth: nil
  },
  {
    username: "donald_k",
    first_name: "Donald",
    last_name: "Knuth",
    email: "donald@example.com",
    role: :member,
    date_of_birth: nil
  }
]

users_data.each do |attrs|
  User.find_or_create_by!(username: attrs[:username]) do |user|
    user.first_name = attrs[:first_name]
    user.last_name = attrs[:last_name]
    user.email = attrs[:email]
    user.role = attrs[:role]
    user.date_of_birth = attrs[:date_of_birth]
    user.password = "password123"
  end
end

puts "Done! Seeded #{User.count} users (#{User.admin.count} admins, #{User.member.count} members)."

# ==============================================================================
# High-Performance Bulk Dataset Generator (using Faker)
# ==============================================================================
# Generates 50k - 100k records using Faker, single-digest BCrypt, and chunked insert_all.
def bulk_seed_users(total_count = 50_000, batch_size = 3_000)
  puts "\nStarting bulk seed of #{total_count} users (batches of #{batch_size})..."
  start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Pre-compute BCrypt hash once to avoid CPU churn on bulk inserts
  password_digest = BCrypt::Password.create("password123", cost: BCrypt::Engine::MIN_COST)
  now = Time.current
  starting_id = (User.maximum(:id) || 0) + 1

  # Pre-sample pools of names for fast generation
  first_names = 200.times.map { Faker::Name.first_name }
  last_names  = 200.times.map { Faker::Name.last_name }

  (0...total_count).each_slice(batch_size) do |batch_indices|
    rows = batch_indices.map do |offset|
      index = starting_id + offset
      fn = first_names[offset % 200]
      ln = last_names[(offset * 7) % 200]
      clean_fn = fn.downcase.gsub(/[^a-z0-9_]/, "")
      clean_ln = ln.downcase.gsub(/[^a-z0-9_]/, "")
      {
        username: "#{clean_fn}_#{index}",
        first_name: fn,
        last_name: ln,
        email: "#{clean_fn}.#{clean_ln}.#{index}@example.com",
        role: 0, # member
        password_digest: password_digest,
        date_of_birth: (offset % 5 == 0) ? nil : (18 + (index % 50)).years.ago.to_date,
        created_at: now,
        updated_at: now
      }
    end

    User.insert_all(rows)
  end

  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).round(2)
  puts "Done! Seeded #{total_count} users in #{elapsed}s. Total users in DB: #{User.count}."
end

# To generate a large dataset for load testing, run:
#   BULK_SEED=true rails db:seed
bulk_seed_users(ENV.fetch("BULK_USERS_COUNT", 50_000).to_i) if ENV["BULK_SEED"] == "true"
