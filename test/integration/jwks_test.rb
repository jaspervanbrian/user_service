require "test_helper"

class JwksTest < ActionDispatch::IntegrationTest
  test "GET /.well-known/jwks.json returns public JWKS" do
    get "/.well-known/jwks.json"

    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type

    json = response.parsed_body
    assert json.key?("keys")
    assert_kind_of Array, json["keys"]
    assert_not_empty json["keys"]

    key = json["keys"].first
    assert_equal "RSA", key["kty"]
    assert key.key?("n")
    assert key.key?("e")
    assert_equal Auth.key_set.signing_kid, key["kid"]

    # Security check: private components are absent
    assert_nil key["d"]
    assert_nil key["p"]
    assert_nil key["q"]
  end
end
