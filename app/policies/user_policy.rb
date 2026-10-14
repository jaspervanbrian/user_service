class UserPolicy < ApplicationPolicy
  PUBLIC_ATTRIBUTES = %i[id username first_name last_name role created_at updated_at].freeze
  PRIVATE_ATTRIBUTES = %i[email date_of_birth].freeze

  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    admin?
  end

  def update?
    admin? || self?
  end

  def destroy?
    admin?
  end

  def update_role?
    admin?
  end

  # ABAC / RBAC: only admins or the user viewing their own record may view private fields (email and date_of_birth).
  def view_private_fields?
    admin? || self?
  end

  def visible_attributes
    if view_private_fields?
      PUBLIC_ATTRIBUTES + PRIVATE_ATTRIBUTES
    else
      PUBLIC_ATTRIBUTES
    end
  end

  def permitted_attributes
    base = %i[first_name last_name username email date_of_birth password password_confirmation]
    update_role? ? (base + [ :role ]) : base
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? ? scope.all : scope.none
    end
  end
end
