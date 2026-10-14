require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @member = users(:member)
    @other_member = users(:member_without_dob)
  end

  test "admin has full permissions on any user" do
    policy = UserPolicy.new(@admin, @member)

    assert policy.index?
    assert policy.show?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
    assert policy.update_role?
    assert policy.view_private_fields?

    expected = %i[id username first_name last_name role created_at updated_at email date_of_birth]
    assert_equal expected, policy.visible_attributes
    assert_includes policy.permitted_attributes, :role
  end

  test "member can view self with private fields and update self" do
    policy = UserPolicy.new(@member, @member)

    assert policy.index?
    assert policy.show?
    assert_not policy.create?
    assert policy.update?
    assert_not policy.destroy?
    assert_not policy.update_role?
    assert policy.view_private_fields?

    expected = %i[id username first_name last_name role created_at updated_at email date_of_birth]
    assert_equal expected, policy.visible_attributes
    assert_not_includes policy.permitted_attributes, :role
  end

  test "member cannot view other member private fields or update other member" do
    policy = UserPolicy.new(@member, @other_member)

    assert policy.index?
    assert policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
    assert_not policy.update_role?
    assert_not policy.view_private_fields?

    expected = %i[id username first_name last_name role created_at updated_at]
    assert_equal expected, policy.visible_attributes
  end

  test "unauthenticated visitor has no permissions" do
    policy = UserPolicy.new(nil, @member)

    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
    assert_not policy.update_role?
    assert_not policy.view_private_fields?

    expected = %i[id username first_name last_name role created_at updated_at]
    assert_equal expected, policy.visible_attributes
  end

  test "scope resolves all for authenticated user and none for unauthenticated visitor" do
    assert_equal User.count, UserPolicy::Scope.new(@member, User.all).resolve.count
    assert_equal 0, UserPolicy::Scope.new(nil, User.all).resolve.count
  end
end
