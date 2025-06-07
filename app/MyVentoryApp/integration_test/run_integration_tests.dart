import 'inventory_page_tests.dart' as inventory_tests;
import 'location_tests.dart' as location_tests;


/// Test Setup
/// All tests begin with a login to access the inventory page:
/// - The app is launched
/// - Login credentials are entered (username: 'alexander', password: 'Alexander123!')
/// - The app navigates to the inventory page after successful login
void main() {
  inventory_tests.main();
  location_tests.main();
  // lending_tests.main();
  // register_tests.main();
}
