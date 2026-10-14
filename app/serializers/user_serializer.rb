class UserSerializer
  attr_reader :resource, :viewer

  def self.render(resource, viewer:)
    new(resource, viewer:).as_json
  end

  def initialize(resource, viewer:)
    @resource = resource
    @viewer = viewer
  end

  def as_json(_options = nil)
    if resource.respond_to?(:map)
      resource.map { |item| serialize_one(item) }
    else
      serialize_one(resource)
    end
  end

  private

  def serialize_one(user)
    return {} if user.nil?

    policy = UserPolicy.new(viewer, user)
    keys = policy.visible_attributes.map(&:to_s)
    user.as_json.slice(*keys)
  end
end
