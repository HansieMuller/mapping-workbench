require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  setup { create_context }

  test "authentication gates the workbench" do
    get root_path
    assert_redirected_to new_session_path
    sign_in
    get root_path
    assert_response :success
    assert_select "h1", "Workbook import history"
    delete session_path
    get root_path
    assert_redirected_to new_session_path
  end
end
