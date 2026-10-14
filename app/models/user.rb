class User < ApplicationRecord
  USERNAME_FORMAT = /\A[A-Za-z0-9_]+\z/

  has_secure_password

  enum :role, { member: 0, admin: 1 }, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }
  # Casing is preserved for display; uniqueness is enforced case-insensitively.
  normalizes :username, with: ->(username) { username.strip }

  validates :first_name, :last_name, presence: true, length: { maximum: 100 }
  # No "@" allowed, so a login value is never ambiguous between username and email.
  validates :username, presence: true,
                       length: { in: 3..30 },
                       format: { with: USERNAME_FORMAT, message: "may only contain letters, numbers and underscores" },
                       uniqueness: { case_sensitive: false }
  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: true
  # has_secure_password already requires a password on create and caps it at 72 bytes (bcrypt limit).
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :date_of_birth_must_be_in_the_past

  # Finds a user by email (when the login contains "@") or by username, case-insensitively.
  def self.find_by_login(login)
    login = login.to_s.strip
    return if login.blank?

    if login.include?("@")
      find_by(email: login.downcase)
    else
      find_by("lower(username) = ?", login.downcase)
    end
  end

  private

  def date_of_birth_must_be_in_the_past
    return if date_of_birth.blank?

    errors.add(:date_of_birth, "must be in the past") unless date_of_birth < Date.current
  end
end
