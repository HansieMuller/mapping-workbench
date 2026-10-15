require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  test "scaffold is runnable" do
    get root_path
    assert_response :success
    assert_select "h1", "MappingWorkbench"
    get rails_health_check_path
    assert_response :success
  end
end
