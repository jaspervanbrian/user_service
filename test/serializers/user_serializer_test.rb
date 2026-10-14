require "test_helper"

class UserSerializerTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @member = users(:member)
    @other_member = users(:member_without_dob)
  end

  test "serializes private fields when viewed by admin" do
    json = UserSerializer.render(@member, viewer: @admin)

    assert_equal @member.id, json["id"]
    assert_equal @member.username, json["username"]
    assert_equal @member.first_name, json["first_name"]
    assert_equal @member.last_name, json["last_name"]
    assert_equal @member.role, json["role"]
    assert_equal @member.email, json["email"]
    assert_equal @member.date_of_birth.as_json, json["date_of_birth"]
    assert_not json.key?("password_digest")
  end

  test "serializes private fields when viewed by self" do
    json = UserSerializer.render(@member, viewer: @member)

    assert_equal @member.email, json["email"]
    assert_equal @member.date_of_birth.as_json, json["date_of_birth"]
  end

  test "omits private fields when viewed by another member" do
    json = UserSerializer.render(@other_member, viewer: @member)

    assert_equal @other_member.id, json["id"]
    assert_equal @other_member.username, json["username"]
    assert_not json.key?("email"), "email should be omitted for other members"
    assert_not json.key?("date_of_birth"), "date_of_birth should be omitted for other members"
    assert_not json.key?("password_digest")
  end

  test "serializes collection with per-record visibility" do
    collection = [ @member, @other_member ]
    json_list = UserSerializer.render(collection, viewer: @member)

    # First item is member viewing self -> includes email
    assert_equal 2, json_list.size
    assert json_list[0].key?("email")
    assert_equal @member.email, json_list[0]["email"]

    # Second item is member viewing other_member -> email omitted
    assert_not json_list[1].key?("email")
    assert_not json_list[1].key?("date_of_birth")
  end
end
