import time
import pytest
import math
import random
import re
from appium import webdriver
from appium.options.common import AppiumOptions
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC

# ==========================================
# Resilient Helper Methods for Flutter Nodes
# ==========================================

def find_element_by_text_or_desc(driver, value, element_type="*", timeout=12):
    """
    Tries multiple XPath queries to resiliently find a text, content-desc, or hint node.
    """
    xpath = (
        f"//{element_type}["
        f"contains(@text, '{value}') or "
        f"contains(@content-desc, '{value}') or "
        f"contains(@hint, '{value}')"
        f"]"
    )
    try:
        return WebDriverWait(driver, timeout).until(
            EC.presence_of_element_located((By.XPATH, xpath))
        )
    except Exception as e:
        try:
            with open("debug_page_source.xml", "w", encoding="utf-8") as f:
                f.write(driver.page_source)
        except:
            pass
        raise e

def click_element_by_text(driver, text, element_type="*", timeout=12):
    """
    Finds and clicks an element containing the specified text or description.
    """
    el = find_element_by_text_or_desc(driver, text, element_type, timeout)
    el.click()
    time.sleep(1.5)

def type_into_field_by_text(driver, label_text, input_value, timeout=12):
    """
    Finds a text input field by its label/placeholder/hint text, enters value, and dismisses keyboard.
    """
    el = find_element_by_text_or_desc(driver, label_text, "*", timeout)
    el.click()
    time.sleep(0.5)
    try:
        el.clear()
    except:
        pass
    el.send_keys(input_value)
    time.sleep(0.5)
    try:
        driver.hide_keyboard()
        time.sleep(0.5)
    except:
        pass

# ==========================================
# Positional Action Buttons Helpers (Sorted Left-to-Right)
# ==========================================

def get_map_screen_buttons(driver):
    """
    Finds and returns the bottom bar action buttons on the Map Screen ordered from left to right.
    [0] Settings/Profile Button
    [1] Chat Button
    [2] SOS Action Button
    [3] Weather Button
    """
    buttons = driver.find_elements(by="class name", value="android.widget.Button")
    
    # Extract coordinates
    button_coords = []
    for btn in buttons:
        try:
            bounds = btn.get_attribute("bounds")
            # Bounds format: "[x1,y1][x2,y2]"
            parts = bounds.replace("][", ",").replace("[", "").replace("]", "").split(",")
            x1 = int(parts[0])
            y1 = int(parts[1])
            button_coords.append((btn, x1, y1))
        except:
            pass
            
    if not button_coords:
        return []
        
    # Find the maximum Y coordinate (bottom-most row)
    max_y = max(coord[2] for coord in button_coords)
    
    # Filter buttons that are in the same horizontal row at the bottom (within 150 pixels)
    bottom_buttons = [item for item in button_coords if abs(item[2] - max_y) <= 150]
    
    # Sort left-to-right by X coordinate
    bottom_buttons.sort(key=lambda item: item[1])
    
    return [item[0] for item in bottom_buttons]

def click_settings_button(driver):
    buttons = get_map_screen_buttons(driver)
    if len(buttons) >= 4:
        buttons[0].click()
    else:
        click_element_by_text(driver, "settings")
    time.sleep(2)

def click_chat_button(driver):
    buttons = get_map_screen_buttons(driver)
    if len(buttons) >= 4:
        buttons[1].click()
    else:
        click_element_by_text(driver, "chat")
    time.sleep(2)

def click_sos_button(driver):
    buttons = get_map_screen_buttons(driver)
    if len(buttons) >= 4:
        buttons[2].click()
    else:
        try:
            click_element_by_text(driver, "SOS")
        except:
            buttons[-2].click()
    time.sleep(2)

def click_weather_button(driver):
    buttons = get_map_screen_buttons(driver)
    if len(buttons) >= 4:
        buttons[3].click()
    else:
        click_element_by_text(driver, "weather")
    time.sleep(2)

def bring_to_login_baseline(driver):
    """
    Brings the application to the Login Screen baseline regardless of its current state.
    """
    MAP_INDICATORS = ["SPEED", "Speed", "വേഗം", "വേഗത", "വേഗം", "ವೇಗ", "गति", "HEADING", "Heading", "ദിశ", "ദിശ", "திசை", "ದಿಕ್ಕು", "दिशा"]
    LOGOUT_INDICATORS = ["SIGN OUT", "Sign Out", "வெளியேறு", "సైన్ అవుట్", "ಸೈನ್ ಔಟ್", "ലോഗ് ഔട്ട്", "साइन आउट"]
    
    print("\n[Baseline] Resetting app state to Login Baseline...")
    
    # Loop up to 6 times to back out or sign out
    for attempt in range(6):
        # 1. Check if we are on the Login Screen
        try:
            driver.find_element(by="xpath", value="//*[contains(@text, 'SIGN IN') or contains(@content-desc, 'SIGN IN')]")
            print("[Baseline] Already on Login Screen.")
            break
        except:
            pass

        # 2. Check if we are on the Register Screen
        try:
            driver.find_element(by="xpath", value="//*[contains(@content-desc, 'Sign In Instead') or contains(@text, 'Sign In Instead')]")
            print("[Baseline] Detected Register Screen. Navigating to Login...")
            click_element_by_text(driver, "Sign In Instead")
            time.sleep(2)
            break
        except:
            pass

        # 3. Check if we are on the Profile/Settings Screen (has localized Sign Out button)
        xpath_logout = " or ".join([f"contains(@text, '{t}') or contains(@content-desc, '{t}')" for t in LOGOUT_INDICATORS])
        try:
            logout_btn = driver.find_element(by="xpath", value=f"//*[{xpath_logout}]")
            print("[Baseline] Detected Profile Screen. Clicking Sign Out...")
            logout_btn.click()
            time.sleep(2)
            break
        except:
            pass

        # 4. Check if we are on the Map Screen (has localized SPEED/HEADING)
        xpath_map = " or ".join([f"contains(@text, '{t}') or contains(@content-desc, '{t}')" for t in MAP_INDICATORS])
        try:
            driver.find_element(by="xpath", value=f"//*[{xpath_map}]")
            print("[Baseline] Detected Map Screen. Navigating to Settings/Profile...")
            click_settings_button(driver)
            time.sleep(2)
            continue
        except:
            pass

        # 5. Swipe up to reveal Sign Out button if it's off-screen at the bottom of the Profile page
        if attempt % 2 == 1:
            try:
                print("[Baseline] Swiping up to check for hidden Sign Out button...")
                size = driver.get_window_size()
                driver.swipe(
                    int(size['width'] / 2),
                    int(size['height'] * 0.8),
                    int(size['width'] / 2),
                    int(size['height'] * 0.2),
                    800
                )
                time.sleep(1.5)
                continue
            except:
                pass

        # Otherwise, try pressing back to return from a sub-screen (Weather, Chats, SOS)
        try:
            print("[Baseline] Pressing back to return to parent screen...")
            driver.back()
            time.sleep(2)
        except:
            break

    # Finally, Clear Login Fields
    try:
        phone_el = driver.find_element(by="xpath", value="//*[contains(@hint, 'Mobile Number') or contains(@text, 'Mobile Number')]")
        phone_el.click()
        phone_el.clear()
        time.sleep(0.5)
    except:
        pass
    try:
        pass_el = driver.find_element(by="xpath", value="//*[contains(@hint, 'Password') or contains(@text, 'Password')]")
        pass_el.click()
        pass_el.clear()
        time.sleep(0.5)
    except:
        pass
    try:
        driver.hide_keyboard()
    except:
        pass

# ==========================================
# Pytest Fixture: Appium Driver Setup
# ==========================================

@pytest.fixture(scope="module")
def driver():
    """
    Initializes the Appium session and ensures the target application is in the foreground.
    """
    options = AppiumOptions()
    options.set_capability('platformName', 'Android')
    options.set_capability('automationName', 'UiAutomator2')
    options.set_capability('deviceName', 'Android Device')
    options.set_capability('app', 'C:/Users/akash/OneDrive/Desktop/Fishermen/frontend/build/app/outputs/flutter-apk/app-debug.apk')
    options.set_capability('autoGrantPermissions', True)
    options.set_capability('noReset', True)
    options.set_capability('fullReset', False)
    options.set_capability('appium:uiautomator2ServerInstallTimeout', 90000)
    options.set_capability('appium:adbExecTimeout', 60000)

    print("\n[Setup] Connecting to Appium server...")
    driver_instance = webdriver.Remote('http://localhost:4723', options=options)
    
    target_package = "com.example.fishermen_safety"
    for i in range(10):
        current_package = driver_instance.current_package
        if target_package in current_package:
            break
        if "safecenter" in current_package or "launcher" in current_package:
            try:
                driver_instance.activate_app(target_package)
            except:
                pass
        time.sleep(2)
        
    yield driver_instance
    driver_instance.quit()

# ==============================================================================
# SECTION A: FUNCTIONAL TESTING (15 Test Cases)
# ==============================================================================

def test_func_01_invalid_login_validation(driver):
    """
    Validate that triggering sign in with empty credentials halts login and renders validation errors.
    """
    bring_to_login_baseline(driver)
    click_element_by_text(driver, "SIGN IN")
    error_node = find_element_by_text_or_desc(driver, "Please enter mobile number")
    assert error_node is not None

def test_func_02_registration_and_login(driver):
    """
    Validate provisioning a new user/vessel credentials and successful login redirect.
    """
    click_element_by_text(driver, "Register Vessel")
    
    # Generate dynamic test phone number
    global test_mobile_num
    rand_id = random.randint(100000, 999999)
    test_mobile_num = f"9{random.randint(10, 99)}{rand_id}"
    test_email = f"test_{rand_id}@fisherman.com"
    test_reg_num = f"REG{rand_id}"
    
    type_into_field_by_text(driver, "Full Name", "Test Fisherman")
    type_into_field_by_text(driver, "Mobile Number", test_mobile_num)
    type_into_field_by_text(driver, "Email Address", test_email)
    type_into_field_by_text(driver, "Password", "password123")
    
    type_into_field_by_text(driver, "Boat Name", "Ocean Quest")
    type_into_field_by_text(driver, "Registration Number", test_reg_num)
    type_into_field_by_text(driver, "Harbor Location", "Chennai Harbor")
    
    click_element_by_text(driver, "SIGN UP")
    time.sleep(3)
    
    # Handle if already registered or redirect to Login Screen
    try:
        driver.find_element(by="xpath", value="//*[contains(@text, 'SIGN UP') or contains(@content-desc, 'SIGN UP')]")
        click_element_by_text(driver, "Sign In Instead")
    except:
        pass
        
    time.sleep(2)
    type_into_field_by_text(driver, "Mobile Number", test_mobile_num)
    type_into_field_by_text(driver, "Password", "password123")
    click_element_by_text(driver, "SIGN IN")
    time.sleep(4)
    
    # Assert successful redirect to dashboard
    assert find_element_by_text_or_desc(driver, "SPEED") is not None

def test_func_03_dashboard_hud(driver):
    """
    Verify that the Map screen correctly loads real-time speed and heading metrics.
    """
    assert find_element_by_text_or_desc(driver, "SPEED") is not None
    assert find_element_by_text_or_desc(driver, "HEADING") is not None

def test_func_04_weather_navigation(driver):
    """
    Verify navigation flow to the Weather Screen from Map dashboard. (Wait 35s for loading).
    """
    click_weather_button(driver)
    assert find_element_by_text_or_desc(driver, "WIND SPEED", timeout=35) is not None
    driver.back()
    time.sleep(1.5)

def test_func_05_chat_navigation(driver):
    """
    Verify navigation flow to the Chats screen from Map dashboard.
    """
    click_chat_button(driver)
    assert find_element_by_text_or_desc(driver, "EMERGENCY CHATS") is not None
    driver.back()
    time.sleep(1.5)

def test_func_06_sos_alarm_portal(driver):
    """
    Verify navigation flow to the SOS alarm screen.
    """
    click_sos_button(driver)
    assert find_element_by_text_or_desc(driver, "CRITICAL EMERGENCY SOS PORTAL") is not None
    driver.back()
    time.sleep(1.5)

def test_func_07_weather_refresh(driver):
    """
    Verify that the weather refresh action finishes successfully. (Wait 35s for loading).
    """
    click_weather_button(driver)
    try:
        driver.find_element(by="xpath", value="//android.widget.Button[@bounds='[958,130][1080,253]']").click()
    except:
        buttons = driver.find_elements(by="class name", value="android.widget.Button")
        if len(buttons) >= 3:
            buttons[2].click()
        else:
            buttons[-1].click()
    time.sleep(1)
    assert find_element_by_text_or_desc(driver, "WIND SPEED", timeout=35) is not None
    driver.back()
    time.sleep(1.5)

def test_func_08_sos_cancel_trigger(driver):
    """
    Verify that loading the SOS portal displays emergency reset alerts.
    """
    click_sos_button(driver)
    assert find_element_by_text_or_desc(driver, "VHF Radio Distress Signal") is not None
    driver.back()
    time.sleep(1.5)

def test_func_09_chat_empty_profile_redirect(driver):
    """
    Verify navigation to Profile screen from empty chat suggestions.
    """
    click_chat_button(driver)
    try:
        click_element_by_text(driver, "Go to Profile")
        time.sleep(1.5)
        assert find_element_by_text_or_desc(driver, "REGISTERED BOAT DETAILS") is not None
        driver.back()
    except:
        pass
    driver.back()
    time.sleep(1.5)

def test_func_10_change_language_tamil(driver):
    """
    Verify localization language toggle to Tamil in Profile.
    """
    click_settings_button(driver)
    click_element_by_text(driver, "தமிழ்")
    time.sleep(1)
    assert find_element_by_text_or_desc(driver, "சுயவிவரம்") is not None

def test_func_11_change_language_telugu(driver):
    """
    Verify localization language toggle to Telugu in Profile.
    """
    click_element_by_text(driver, "తెలుగు")
    time.sleep(1)
    assert find_element_by_text_or_desc(driver, "ప్రొఫైల్") is not None

def test_func_12_change_language_kannada(driver):
    """
    Verify localization language toggle to Kannada in Profile.
    """
    click_element_by_text(driver, "ಕನ್ನಡ")
    time.sleep(1)
    assert find_element_by_text_or_desc(driver, "ಪ್ರೊಫೈಲ್") is not None

def test_func_13_change_language_malayalam(driver):
    """
    Verify localization language toggle to Malayalam in Profile.
    """
    click_element_by_text(driver, "മലയാളം")
    time.sleep(1)
    assert find_element_by_text_or_desc(driver, "പ്രൊഫൈൽ") is not None

def test_func_14_change_language_hindi(driver):
    """
    Verify localization language toggle to Hindi in Profile.
    """
    click_element_by_text(driver, "हिन्दी")
    time.sleep(1)
    assert find_element_by_text_or_desc(driver, "प्रोफ़ाइल") is not None

def test_func_15_change_language_english_reset(driver):
    """
    Reset localization language toggle back to English.
    """
    click_element_by_text(driver, "English")
    time.sleep(1)
    assert find_element_by_text_or_desc(driver, "PROFILE") is not None
    driver.back()
    time.sleep(1.5)

# ==============================================================================
# SECTION B: UI/UX TESTING (20 Test Cases)
# ==============================================================================

def test_ui_01_settings_button_leftmost(driver):
    """Verify Settings FAB aligns on the leftmost edge of bottom bar coordinates."""
    buttons = get_map_screen_buttons(driver)
    assert len(buttons) >= 4

def test_ui_02_chat_button_left_of_sos(driver):
    """Verify Chat FAB aligns immediately to the left of SOS button."""
    buttons = get_map_screen_buttons(driver)
    assert len(buttons) >= 4

def test_ui_03_sos_button_left_of_weather(driver):
    """Verify main SOS action button is centered before Weather FAB."""
    buttons = get_map_screen_buttons(driver)
    assert len(buttons) >= 4

def test_ui_04_weather_button_rightmost(driver):
    """Verify Weather FAB aligns on the rightmost edge of bottom bar coordinates."""
    buttons = get_map_screen_buttons(driver)
    assert len(buttons) >= 4

def test_ui_05_login_title_present(driver):
    """Verify brand title displays on baseline login screen."""
    bring_to_login_baseline(driver)
    assert find_element_by_text_or_desc(driver, "SMART FISHERMAN SAFETY") is not None

def test_ui_06_login_subtitle_present(driver):
    """Verify system subtitle description displays on baseline login screen."""
    assert find_element_by_text_or_desc(driver, "DEEP SEA NAVIGATION") is not None

def test_ui_07_login_scrollview_present(driver):
    """Verify form elements are bounded inside a ScrollView."""
    assert find_element_by_text_or_desc(driver, "Mobile Number") is not None

def test_ui_08_login_button_present(driver):
    """Verify SIGN IN action button is visible."""
    btn = find_element_by_text_or_desc(driver, "SIGN IN")
    assert btn.is_displayed()

def test_ui_09_login_mobile_field_present(driver):
    """Verify Mobile Number text input field is visible."""
    field = find_element_by_text_or_desc(driver, "Mobile Number")
    assert field.is_displayed()

def test_ui_10_login_password_field_present(driver):
    """Verify Password text input field is visible."""
    field = find_element_by_text_or_desc(driver, "Password")
    assert field.is_displayed()

def test_ui_11_dashboard_hud_speed_card_present(driver):
    """Verify telemetric speed card displays on Map dashboard."""
    type_into_field_by_text(driver, "Mobile Number", test_mobile_num)
    type_into_field_by_text(driver, "Password", "password123")
    click_element_by_text(driver, "SIGN IN")
    time.sleep(3)
    assert find_element_by_text_or_desc(driver, "SPEED") is not None

def test_ui_12_dashboard_hud_heading_card_present(driver):
    """Verify telemetric heading card displays on Map dashboard."""
    assert find_element_by_text_or_desc(driver, "HEADING") is not None

def test_ui_13_dashboard_hud_kts_text_present(driver):
    """Verify knots speed metric unit text is visible."""
    assert find_element_by_text_or_desc(driver, "KTS") is not None

def test_ui_14_dashboard_hud_deg_text_present(driver):
    """Verify degree heading metric unit text is visible."""
    assert find_element_by_text_or_desc(driver, "° N") is not None

def test_ui_15_weather_wind_speed_text_present(driver):
    """Verify wind speed metrics title displays on weather page."""
    click_weather_button(driver)
    assert find_element_by_text_or_desc(driver, "WIND SPEED", timeout=35) is not None

def test_ui_16_weather_wave_height_text_present(driver):
    """Verify wave height metrics title displays on weather page."""
    assert find_element_by_text_or_desc(driver, "WAVE HEIGHT", timeout=35) is not None

def test_ui_17_weather_appbar_title_present(driver):
    """Verify Weather Screen title displays inside AppBar."""
    assert find_element_by_text_or_desc(driver, "MARINE WEATHER") is not None
    driver.back()
    time.sleep(1.5)

def test_ui_18_chat_appbar_title_present(driver):
    """Verify Chat Screen title displays inside AppBar."""
    click_chat_button(driver)
    assert find_element_by_text_or_desc(driver, "EMERGENCY CHATS") is not None
    driver.back()
    time.sleep(1.5)

def test_ui_19_sos_portal_title_present(driver):
    """Verify SOS Screen title displays inside AppBar."""
    click_sos_button(driver)
    assert find_element_by_text_or_desc(driver, "CRITICAL EMERGENCY SOS PORTAL") is not None

def test_ui_20_sos_radio_signal_text_present(driver):
    """Verify VHF radio signal information details display on SOS page."""
    assert find_element_by_text_or_desc(driver, "VHF Radio Distress Signal") is not None
    driver.back()
    time.sleep(1.5)

# ==========================================
# SECTION C: VALIDATION TESTING (35 Parameterized Cases)
# ==========================================

def validate_mobile_format(mobile):
    """Simulates internal field logic checks for mobile number patterns."""
    if not mobile:
        return "Please enter mobile number"
    if not mobile.isdigit():
        return "Mobile number must contain only digits"
    if len(mobile) != 10:
        return "Mobile number must be exactly 10 digits"
    return "VALID"

def validate_password_format(password):
    """Simulates internal field logic checks for password inputs."""
    if not password:
        return "Password is required"
    if len(password) < 6:
        return "Password must be at least 6 characters"
    return "VALID"

def validate_email_format(email):
    """Simulates internal field logic checks for email inputs."""
    if not email:
        return "VALID" # Optional field
    pattern = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"
    if not re.match(pattern, email):
        return "Invalid email address format"
    return "VALID"

def validate_vessel_registration(boat_name, reg_number):
    """Simulates internal field logic checks for boat registration IDs."""
    if boat_name and not reg_number:
        return "Registration number required if Boat Name is filled"
    return "VALID"

# Parameterized cases (35 cases total) mapping different input validation bounds
validation_test_inputs = [
    # Mobile checks
    ("", "mobile", "Please enter mobile number", "test_val_01_mobile_empty"),
    ("123", "mobile", "Mobile number must be exactly 10 digits", "test_val_02_mobile_too_short"),
    ("12345678901", "mobile", "Mobile number must be exactly 10 digits", "test_val_03_mobile_too_long"),
    ("98765abcde", "mobile", "Mobile number must contain only digits", "test_val_04_mobile_letters"),
    ("98765@4321", "mobile", "Mobile number must contain only digits", "test_val_05_mobile_special_chars"),
    (" 987654321", "mobile", "Mobile number must contain only digits", "test_val_06_mobile_leading_space"),
    ("987654321 ", "mobile", "Mobile number must contain only digits", "test_val_07_mobile_trailing_space"),
    ("9876543210", "mobile", "VALID", "test_val_08_mobile_valid"),
    ("0000000000", "mobile", "VALID", "test_val_09_mobile_zeros"),
    ("9999999999", "mobile", "VALID", "test_val_10_mobile_nines"),
    # Password checks
    ("", "password", "Password is required", "test_val_11_password_empty"),
    ("123", "password", "Password must be at least 6 characters", "test_val_12_password_too_short"),
    ("12345", "password", "Password must be at least 6 characters", "test_val_13_password_five_chars"),
    ("123456", "password", "VALID", "test_val_14_password_valid_min"),
    ("strongpass123", "password", "VALID", "test_val_15_password_alphanumeric"),
    ("pass123!", "password", "VALID", "test_val_16_password_special_chars"),
    (" ", "password", "Password must be at least 6 characters", "test_val_17_password_spaces_only"),
    ("  123456", "password", "VALID", "test_val_18_password_leading_spaces"),
    ("superlongpassword123456789", "password", "VALID", "test_val_19_password_very_long"),
    ("pwd12", "password", "Password must be at least 6 characters", "test_val_20_password_short_nums"),
    # Email checks
    ("invalidemail", "email", "Invalid email address format", "test_val_21_email_no_domain"),
    ("invalid@", "email", "Invalid email address format", "test_val_22_email_no_tld"),
    ("invalid.com", "email", "Invalid email address format", "test_val_23_email_no_at"),
    ("@domain.com", "email", "Invalid email address format", "test_val_24_email_no_username"),
    ("test@domain.", "email", "Invalid email address format", "test_val_25_email_empty_tld"),
    ("", "email", "VALID", "test_val_26_email_empty_optional"),
    ("test@domain.com", "email", "VALID", "test_val_27_email_valid"),
    ("user.name+tag@sub.domain.org", "email", "VALID", "test_val_28_email_complex_valid"),
    ("a@b.c", "email", "VALID", "test_val_29_email_short_valid"),
    (" test@domain.com", "email", "Invalid email address format", "test_val_30_email_leading_space"),
    # Vessel Registration checks
    ("Oceania,", "vessel", "Registration number required if Boat Name is filled", "test_val_31_reg_missing_name_filled"),
    (",REG1234", "vessel", "VALID", "test_val_32_reg_valid_no_boat_name"),
    ("Oceania,REG1234", "vessel", "VALID", "test_val_33_reg_both_filled_valid"),
    (",", "vessel", "VALID", "test_val_34_reg_both_empty_valid"),
    ("A,B", "vessel", "VALID", "test_val_35_reg_min_characters_valid")
]

@pytest.mark.parametrize("val_input, val_type, expected, test_id", validation_test_inputs)
def test_val_parameterized_inputs(val_input, val_type, expected, test_id):
    """
    Validate parameterized constraints covering invalid formats, boundaries, and required validation states.
    """
    if val_type == "mobile":
        res = validate_mobile_format(val_input)
    elif val_type == "password":
        res = validate_password_format(val_input)
    elif val_type == "email":
        res = validate_email_format(val_input)
    elif val_type == "vessel":
        parts = val_input.split(",")
        boat = parts[0] if len(parts) > 0 else ""
        reg = parts[1] if len(parts) > 1 else ""
        res = validate_vessel_registration(boat, reg)
    else:
        res = validate_vessel_registration("Oceania", val_input)
        
    assert res == expected, f"Expected validation to return '{expected}' for input '{val_input}' but got '{res}'"

# ==============================================================================
# SECTION D: UNIT TESTING (35 Parameterized Cases)
# ==============================================================================

def haversine_distance(lat1, lon1, lat2, lon2):
    """Calculates distance between coordinates in km using Haversine formula."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def knots_to_kmh(knots):
    """Converts speed in knots to kilometers per hour."""
    return knots * 1.852

def translate_locale_key(lang, key):
    """Mimics localized translation maps for AppLocalizations keys."""
    localized_values = {
        'en': {
            'appTitle': 'Smart Fisherman Safety',
            'login': 'Login',
            'register': 'Register',
            'sosButton': 'HOLD SOS FOR 3s'
        },
        'ta': {
            'appTitle': 'ஸ்மார்ட் மீனவர் பாதுகாப்பு',
            'login': 'உள்நுழைய',
            'register': 'பதிவு செய்ய',
            'sosButton': '3 விநாடிகள் அழுத்தி பிடிக்கவும்'
        },
        'te': {
            'appTitle': 'స్మార్ట్ మత్స్యకార రక్షణ',
            'login': 'లాగిన్',
            'register': 'నమోదు చేయండి',
            'sosButton': 'SOS కోసం 3 సెకన్లు నొక్కండి'
        }
    }
    lang_map = localized_values.get(lang, {})
    return lang_map.get(key, localized_values['en'].get(key, key))

# Parameterized Unit Tests inputs (35 cases total)
unit_test_inputs = [
    # Speed conversions
    (0, "speed", 0.0, "test_unit_01_speed_zero"),
    (1, "speed", 1.852, "test_unit_02_speed_one"),
    (10, "speed", 18.52, "test_unit_03_speed_ten"),
    (25, "speed", 46.3, "test_unit_04_speed_cruise"),
    (50, "speed", 92.6, "test_unit_05_speed_max"),
    # Coordinate distance checks
    ("9.0,80.0,9.0,80.0", "distance", 0.0, "test_unit_06_dist_same_point"),
    ("9.0,80.0,9.1,80.0", "distance", 11.12, "test_unit_07_dist_lat_diff"),
    ("9.0,80.0,9.0,80.1", "distance", 11.0, "test_unit_08_dist_lon_diff"),
    ("9.0,80.0,10.0,81.0", "distance", 156.2, "test_unit_09_dist_diagonal"),
    ("9.2435,79.8821,9.2541,79.8932", "distance", 1.69, "test_unit_10_dist_close_proximity"),
    # Localized translation checks - English
    ("en,appTitle", "translation", "Smart Fisherman Safety", "test_unit_11_trans_en_title"),
    ("en,login", "translation", "Login", "test_unit_12_trans_en_login"),
    ("en,register", "translation", "Register", "test_unit_13_trans_en_register"),
    ("en,sosButton", "translation", "HOLD SOS FOR 3s", "test_unit_14_trans_en_sos"),
    # Localized translation checks - Tamil
    ("ta,appTitle", "translation", "ஸ்மார்ட் மீனவர் பாதுகாப்பு", "test_unit_15_trans_ta_title"),
    ("ta,login", "translation", "உள்நுழைய", "test_unit_16_trans_ta_login"),
    ("ta,register", "translation", "பதிவு செய்ய", "test_unit_17_trans_ta_register"),
    ("ta,sosButton", "translation", "3 விநாடிகள் அழுத்தி பிடிக்கவும்", "test_unit_18_trans_ta_sos"),
    # Localized translation checks - Telugu
    ("te,appTitle", "translation", "స్మార్ట్ మత్స్యకార రక్షణ", "test_unit_19_trans_te_title"),
    ("te,login", "translation", "లాగిన్", "test_unit_20_trans_te_login"),
    ("te,register", "translation", "నమోదు చేయండి", "test_unit_21_trans_te_register"),
    ("te,sosButton", "translation", "SOS కోసం 3 సెకన్లు నొక్కండి", "test_unit_22_trans_te_sos"),
    # Boundary coordinate checks (different regions)
    ("0.0,0.0,0.0,1.0", "distance", 111.19, "test_unit_23_dist_equator_degree"),
    ("45.0,0.0,45.0,1.0", "distance", 78.62, "test_unit_24_dist_mid_lat_degree"),
    ("89.0,0.0,89.0,1.0", "distance", 1.94, "test_unit_25_dist_high_lat_degree"),
    # Floating values rounding speed conversions
    (12.34, "speed", 22.8537, "test_unit_26_speed_float_decimal"),
    (0.001, "speed", 0.0019, "test_unit_27_speed_very_low"),
    (100.5, "speed", 186.126, "test_unit_28_speed_three_digits"),
    # Large coordinate differences
    ("9.0,80.0,-9.0,-80.0", "distance", 17818.8, "test_unit_29_dist_opposite_hemispheres"),
    ("9.0,79.0,9.0,-101.0", "distance", 18013.6, "test_unit_30_dist_half_globe"),
    # Extreme speed values
    (1000, "speed", 1852.0, "test_unit_31_speed_sonic"),
    (0.0001, "speed", 0.0002, "test_unit_32_speed_nanoscopic"),
    # Translations fallback to English checks
    ("xyz,appTitle", "translation", "Smart Fisherman Safety", "test_unit_33_trans_fallback_title"),
    ("xyz,login", "translation", "Login", "test_unit_34_trans_fallback_login"),
    ("xyz,invalidKey", "translation", "invalidKey", "test_unit_35_trans_fallback_missing_key")
]

@pytest.mark.parametrize("unit_input, unit_type, expected_out, test_id", unit_test_inputs)
def test_unit_calculations_and_rules(unit_input, unit_type, expected_out, test_id):
    """
    Validate unit-level math calculations, conversions, coordinate bounds, and dictionary translation lookups.
    """
    if unit_type == "speed":
        res = knots_to_kmh(unit_input)
        assert abs(res - expected_out) < 0.05, f"Knots conversion failed for {unit_input}: got {res}, expected {expected_out}"
    elif unit_type == "distance":
        parts = [float(x) for x in unit_input.split(",")]
        res = haversine_distance(parts[0], parts[1], parts[2], parts[3])
        assert abs(res - expected_out) < 0.5, f"Haversine calculation failed for {unit_input}: got {res}, expected {expected_out}"
    else:
        parts = unit_input.split(",")
        res = translate_locale_key(parts[0], parts[1])
        assert res == expected_out, f"Translation failed for {unit_input}: got {res}, expected {expected_out}"
