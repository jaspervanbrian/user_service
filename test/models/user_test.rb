require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid fixture users are valid" do
    assert users(:admin).valid?
    assert users(:member).valid?
    assert users(:member_without_dob).valid?
  end

  test "requires presence of first_name, last_name, username, and email" do
    user = User.new
    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
    assert_includes user.errors[:last_name], "can't be blank"
    assert_includes user.errors[:username], "can't be blank"
    assert_includes user.errors[:email], "can't be blank"
  end

  test "validates username format and length" do
    user = User.new(
      first_name: "John",
      last_name: "Doe",
      email: "john@example.com",
      password: "password123"
    )

    user.username = "ab"
    assert_not user.valid?
    assert_includes user.errors[:username], "is too short (minimum is 3 characters)"

    user.username = "a" * 31
    assert_not user.valid?
    assert_includes user.errors[:username], "is too long (maximum is 30 characters)"

    user.username = "john@doe"
    assert_not user.valid?
    assert_includes user.errors[:username], "may only contain letters, numbers and underscores"

    user.username = "john doe"
    assert_not user.valid?

    user.username = "John_Doe_99"
    assert user.valid?
  end

  test "preserves username casing on save" do
    user = User.create!(
      username: "  JohnDoe  ",
      first_name: "John",
      last_name: "Doe",
      email: "johndoe@example.com",
      password: "password123"
    )

    assert_equal "JohnDoe", user.reload.username
  end

  test "enforces case-insensitive username uniqueness at validation level" do
    existing = users(:admin) # AdaAdmin
    duplicate = User.new(
      username: existing.username.downcase,
      first_name: "Other",
      last_name: "Person",
      email: "other@example.com",
      password: "password123"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:username], "has already been taken"
  end

  test "enforces case-insensitive username uniqueness at database index level" do
    existing = users(:admin) # AdaAdmin
    duplicate = User.new(
      username: existing.username.downcase,
      first_name: "Other",
      last_name: "Person",
      email: "unique_email@example.com",
      password: "password123"
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!(validate: false)
    end
  end

  test "normalizes email to lowercase and strips whitespace" do
    user = User.create!(
      username: "unique_user",
      first_name: "Unique",
      last_name: "User",
      email: "  NEW_USER@Example.COM  ",
      password: "password123"
    )

    assert_equal "new_user@example.com", user.reload.email
  end

  test "validates email uniqueness" do
    existing = users(:member)
    duplicate = User.new(
      username: "different_user",
      first_name: "Other",
      last_name: "Person",
      email: existing.email.upcase,
      password: "password123"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "date_of_birth is optional but must be in the past when provided" do
    user = users(:member_without_dob)
    assert_nil user.date_of_birth
    assert user.valid?

    user.date_of_birth = Date.current
    assert_not user.valid?
    assert_includes user.errors[:date_of_birth], "must be in the past"

    user.date_of_birth = Date.tomorrow
    assert_not user.valid?
    assert_includes user.errors[:date_of_birth], "must be in the past"

    user.date_of_birth = 20.years.ago.to_date
    assert user.valid?
  end

  test "enforces password minimum length of 8 characters" do
    user = User.new(
      username: "pass_user",
      first_name: "Pass",
      last_name: "User",
      email: "pass@example.com",
      password: "short"
    )

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"

    user.password = "validpassword"
    assert user.valid?
  end

  test "allows updating user attributes without re-supplying password" do
    user = users(:member)
    assert user.update(first_name: "Michael")
    assert_equal "Michael", user.reload.first_name
  end

  test "authenticates password using has_secure_password" do
    user = users(:admin)
    assert user.authenticate("password123")
    assert_not user.authenticate("wrongpassword")
  end

  test "find_by_login looks up by email or username case-insensitively" do
    admin = users(:admin) # username: AdaAdmin, email: ada@example.com

    assert_equal admin, User.find_by_login("ada@example.com")
    assert_equal admin, User.find_by_login("ADA@EXAMPLE.COM")
    assert_equal admin, User.find_by_login("AdaAdmin")
    assert_equal admin, User.find_by_login("adaadmin")
    assert_equal admin, User.find_by_login("  ADAADMIN  ")

    assert_nil User.find_by_login("nonexistent")
    assert_nil User.find_by_login("nonexistent@example.com")
    assert_nil User.find_by_login("")
    assert_nil User.find_by_login(nil)
  end

  test "default role is member" do
    user = User.new
    assert_equal "member", user.role
    assert user.member?
  end
end
