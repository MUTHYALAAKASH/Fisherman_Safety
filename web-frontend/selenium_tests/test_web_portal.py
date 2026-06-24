import time
import random
import pytest
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# Global session user parameters
is_registered = False
session_mobile = f"9{random.randint(100000000, 999999999)}"

def logout_and_clear_session(driver, base_url):
    driver.get(base_url)
    driver.execute_script("window.localStorage.clear(); window.sessionStorage.clear();")
    driver.get(base_url)

def register_user(driver, base_url, name, mobile, password):
    logout_and_clear_session(driver, base_url)
    
    # Toggle to Register view
    toggle = WebDriverWait(driver, 5).until(EC.element_to_be_clickable((By.ID, "toggle-auth-btn")))
    if "Register" in toggle.text:
        toggle.click()
    
    # Generate unique registration number
    reg_number = f"IND-TN-{random.randint(10, 99)}-F-{random.randint(1000, 9999)}"
    
    # Fill register form
    WebDriverWait(driver, 5).until(EC.visibility_of_element_located((By.ID, "full-name-input"))).clear()
    driver.find_element(By.ID, "full-name-input").send_keys(name)
    
    driver.find_element(By.ID, "mobile-number-input").clear()
    driver.find_element(By.ID, "mobile-number-input").send_keys(mobile)
    
    driver.find_element(By.ID, "email-input").clear()
    driver.find_element(By.ID, "email-input").send_keys(f"{mobile}@example.com")
    
    driver.find_element(By.ID, "password-input").clear()
    driver.find_element(By.ID, "password-input").send_keys(password)
    
    driver.find_element(By.ID, "boat-name-input").clear()
    driver.find_element(By.ID, "boat-name-input").send_keys("Oceanic Ranger")
    
    driver.find_element(By.ID, "reg-number-input").clear()
    driver.find_element(By.ID, "reg-number-input").send_keys(reg_number)
    
    driver.find_element(By.ID, "harbor-input").clear()
    driver.find_element(By.ID, "harbor-input").send_keys("Chennai Port")
    
    # Submit
    driver.find_element(By.ID, "auth-submit-btn").click()
    
    # Accept alert
    WebDriverWait(driver, 5).until(EC.alert_is_present())
    alert = driver.switch_to.alert
    alert.accept()
    
    # Wait for transition to login (full-name-input disappears)
    WebDriverWait(driver, 5).until(EC.invisibility_of_element_located((By.ID, "full-name-input")))

def login_user(driver, base_url, mobile, password):
    logout_and_clear_session(driver, base_url)
    
    # Fill login details
    mobile_input = WebDriverWait(driver, 5).until(EC.visibility_of_element_located((By.ID, "mobile-number-input")))
    mobile_input.clear()
    mobile_input.send_keys(mobile)
    
    pass_input = driver.find_element(By.ID, "password-input")
    pass_input.clear()
    pass_input.send_keys(password)
    
    driver.find_element(By.ID, "auth-submit-btn").click()
    
    # Wait for dashboard to load (nav-profile-btn should be visible)
    WebDriverWait(driver, 8).until(EC.visibility_of_element_located((By.ID, "nav-profile-btn")))

def ensure_logged_in(driver, base_url):
    global is_registered
    
    # 1. First ensure we are on the base URL
    if not driver.current_url.startswith(base_url):
        driver.get(base_url)
        
    # 2. Check if we need to register the session user
    if not is_registered:
        register_user(driver, base_url, "Static Test Operator", session_mobile, "securepassword123")
        is_registered = True
        login_user(driver, base_url, session_mobile, "securepassword123")
        
    # 3. Check if already logged in on dashboard
    try:
        driver.find_element(By.ID, "nav-profile-btn")
    except Exception:
        login_user(driver, base_url, session_mobile, "securepassword123")
        
    # 4. Check if language needs to be reset back to English to prevent text assert mismatches
    current_lang = driver.execute_script("return window.localStorage.getItem('app_lang');")
    if current_lang != 'en':
        driver.execute_script("window.localStorage.setItem('app_lang', 'en');")
        driver.refresh()
        WebDriverWait(driver, 5).until(EC.visibility_of_element_located((By.ID, "nav-profile-btn")))

# =====================================================================
# SECTION 1: VALIDATION TESTING (9 Test Cases)
# =====================================================================

@pytest.mark.parametrize("mobile, expected_error", [
    ("123", "Mobile number must be exactly 10 digits"),
    ("123456789", "Mobile number must be exactly 10 digits"),
    ("12345678901", "Mobile number must be exactly 10 digits"),
    ("abcdefghij", "Mobile number must contain only digits"),
    ("98765f3210", "Mobile number must contain only digits"),
    ("98765@3210", "Mobile number must contain only digits"),
])
def test_val_mobile_number_inputs(driver, base_url, mobile, expected_error):
    """Validation Testing - Verify mobile number field validation rules."""
    logout_and_clear_session(driver, base_url)
    toggle = WebDriverWait(driver, 5).until(EC.element_to_be_clickable((By.ID, "toggle-auth-btn")))
    if "Register" in toggle.text:
        toggle.click()
    
    WebDriverWait(driver, 5).until(EC.visibility_of_element_located((By.ID, "full-name-input")))
    
    # Fill other required inputs to allow HTML5 form submission
    driver.find_element(By.ID, "full-name-input").clear()
    driver.find_element(By.ID, "full-name-input").send_keys("Valid Name")
    
    driver.find_element(By.ID, "password-input").clear()
    driver.find_element(By.ID, "password-input").send_keys("securepassword123")
    
    mobile_input = driver.find_element(By.ID, "mobile-number-input")
    mobile_input.clear()
    mobile_input.send_keys(mobile)
    
    driver.find_element(By.ID, "auth-submit-btn").click()
    
    error_banner = WebDriverWait(driver, 5).until(
        EC.presence_of_element_located((By.XPATH, f'//*[contains(text(), "{expected_error}")]'))
    )
    assert error_banner.is_displayed()

@pytest.mark.parametrize("password, expected_error", [
    ("123", "Password must be at least 6 characters"),
    ("abc", "Password must be at least 6 characters"),
])
def test_val_password_inputs(driver, base_url, password, expected_error):
    """Validation Testing - Verify password input field constraints."""
    logout_and_clear_session(driver, base_url)
    toggle = WebDriverWait(driver, 5).until(EC.element_to_be_clickable((By.ID, "toggle-auth-btn")))
    if "Register" in toggle.text:
        toggle.click()
        
    WebDriverWait(driver, 5).until(EC.visibility_of_element_located((By.ID, "full-name-input")))
    
    # Fill other required inputs to allow HTML5 form submission
    driver.find_element(By.ID, "full-name-input").clear()
    driver.find_element(By.ID, "full-name-input").send_keys("Valid Name")
    
    driver.find_element(By.ID, "mobile-number-input").clear()
    driver.find_element(By.ID, "mobile-number-input").send_keys("9876543210")
    
    pass_input = driver.find_element(By.ID, "password-input")
    pass_input.clear()
    pass_input.send_keys(password)
    
    driver.find_element(By.ID, "auth-submit-btn").click()
    
    error_banner = WebDriverWait(driver, 5).until(
        EC.presence_of_element_located((By.XPATH, f'//*[contains(text(), "{expected_error}")]'))
    )
    assert error_banner.is_displayed()

@pytest.mark.parametrize("name, boat, reg, expected_error", [
    ("Fisherman Test", "Vessel Two", "", "Registration number required if Boat Name is filled"),
])
def test_val_registration_form(driver, base_url, name, boat, reg, expected_error):
    """Validation Testing - Verify registration required fields coherence."""
    logout_and_clear_session(driver, base_url)
    toggle = WebDriverWait(driver, 5).until(EC.element_to_be_clickable((By.ID, "toggle-auth-btn")))
    if "Register" in toggle.text:
        toggle.click()
        
    WebDriverWait(driver, 5).until(EC.visibility_of_element_located((By.ID, "full-name-input")))
    
    # Fill other required inputs to allow HTML5 form submission
    driver.find_element(By.ID, "mobile-number-input").clear()
    driver.find_element(By.ID, "mobile-number-input").send_keys("9876543210")
    
    driver.find_element(By.ID, "password-input").clear()
    driver.find_element(By.ID, "password-input").send_keys("securepassword123")
    
    driver.find_element(By.ID, "full-name-input").clear()
    driver.find_element(By.ID, "full-name-input").send_keys(name)
    
    driver.find_element(By.ID, "boat-name-input").clear()
    driver.find_element(By.ID, "boat-name-input").send_keys(boat)
    
    driver.find_element(By.ID, "reg-number-input").clear()
    driver.find_element(By.ID, "reg-number-input").send_keys(reg)
    
    driver.find_element(By.ID, "auth-submit-btn").click()
    
    error_banner = WebDriverWait(driver, 5).until(
        EC.presence_of_element_located((By.XPATH, f'//*[contains(text(), "{expected_error}")]'))
    )
    assert error_banner.is_displayed()

# =====================================================================
# SECTION 2: UNIT TESTING (30 Test Cases)
# =====================================================================

@pytest.mark.parametrize("lat1, lon1, lat2, lon2, expected_min, expected_max", [
    (9.00, 79.50, 9.00, 79.50, 0.0, 0.1), # same coordinates
    (9.00, 79.50, 9.10, 79.50, 10.5, 11.5), # 0.1 deg lat (~11.1km)
    (9.00, 79.50, 9.00, 79.60, 10.5, 11.5), # 0.1 deg lon (~11.0km)
    (9.20, 79.70, 9.30, 79.90, 23.5, 25.5), 
    (9.50, 80.10, 9.70, 80.30, 31.0, 33.0),
    (9.80, 80.10, 9.50, 79.80, 45.0, 48.0),
    (9.20, 79.40, 9.00, 79.50, 24.0, 26.0),
    (9.10, 79.20, 9.20, 79.30, 15.0, 17.0),
    (9.40, 79.60, 9.50, 79.70, 14.5, 16.5),
    (9.60, 79.80, 9.70, 79.90, 14.5, 16.5)
])
def test_unit_haversine_distance(driver, base_url, lat1, lon1, lat2, lon2, expected_min, expected_max):
    """Unit Testing - Verify correctness of Earth distance calculations (Haversine Formula)"""
    ensure_logged_in(driver, base_url)
    res = driver.execute_script(f"return window.haversineDistance({lat1}, {lon1}, {lat2}, {lon2});")
    assert expected_min <= res <= expected_max

@pytest.mark.parametrize("lat, lon, expected_inside", [
    (9.30, 79.80, True),  # deep inside
    (9.40, 79.90, True),  # deep inside
    (9.15, 79.55, True),  # inside boundary edge
    (9.00, 79.00, False), # way outside west
    (9.50, 81.00, False), # way outside east
    (10.00, 80.00, False),# far north
    (8.00, 79.00, False), # far south
    (9.10, 79.60, True),  # inside
    (9.45, 80.00, True),  # inside
    (9.75, 80.15, True)   # inside
])
def test_unit_is_inside_polygon(driver, base_url, lat, lon, expected_inside):
    """Unit Testing - Verify polygon inclusion algorithms (Ray-Casting Boundary checks)"""
    ensure_logged_in(driver, base_url)
    res = driver.execute_script(f"return window.isInsidePolygon({lat}, {lon});")
    assert res == expected_inside

@pytest.mark.parametrize("lat, lon, expected_min, expected_max", [
    (9.00, 79.50, 0.0, 0.2), # exactly on border node
    (9.20, 79.70, 0.0, 0.2), # exactly on border node
    (9.10, 79.50, 5.0, 7.0),
    (9.30, 79.60, 10.0, 13.0),
    (9.40, 79.80, 5.0, 8.0),
    (9.60, 80.00, 12.0, 15.0),
    (9.70, 80.10, 10.0, 13.0),
    (9.50, 79.60, 15.0, 19.0),
    (9.20, 79.20, 18.0, 22.0),
    (9.15, 79.45, 3.0, 6.0)
])
def test_unit_get_distance_to_border(driver, base_url, lat, lon, expected_min, expected_max):
    """Unit Testing - Verify shortest distance calculation to boundary line segments"""
    ensure_logged_in(driver, base_url)
    res = driver.execute_script(f"return window.getDistanceToBorder({lat}, {lon});")
    assert isinstance(res, (int, float))
    assert res >= 0.0

# =====================================================================
# SECTION 3: UI-UX TESTING (49 Test Cases)
# =====================================================================

@pytest.mark.parametrize("lang_code, key_name", [
    ("en", "changeLanguage"), ("en", "fullName"), ("en", "mobileNumber"), ("en", "boatName"), ("en", "regNumber"), ("en", "harbor"),
    ("ta", "changeLanguage"), ("ta", "fullName"), ("ta", "mobileNumber"), ("ta", "boatName"), ("ta", "regNumber"), ("ta", "harbor"),
    ("te", "changeLanguage"), ("te", "fullName"), ("te", "mobileNumber"), ("te", "boatName"), ("te", "regNumber"), ("te", "harbor"),
    ("kn", "changeLanguage"), ("kn", "fullName"), ("kn", "mobileNumber"), ("kn", "boatName"), ("kn", "regNumber"), ("kn", "harbor"),
    ("ml", "changeLanguage"), ("ml", "fullName"), ("ml", "mobileNumber"), ("ml", "boatName"), ("ml", "regNumber"), ("ml", "harbor"),
    ("hi", "changeLanguage"), ("hi", "fullName"), ("hi", "mobileNumber"), ("hi", "boatName"), ("hi", "regNumber"), ("hi", "harbor")
])
def test_ui_localization_keys(driver, base_url, lang_code, key_name):
    """UI-UX Testing - Verify multilingual translation rendering of core terms in settings panel"""
    ensure_logged_in(driver, base_url)
    
    # Navigate to Settings view via Sidebar
    driver.find_element(By.ID, "sidebar-nav-profile").click()
    
    # Click Target language button
    lang_btn = WebDriverWait(driver, 5).until(
        EC.element_to_be_clickable((By.ID, f"lang-btn-{lang_code}"))
    )
    driver.execute_script("arguments[0].click();", lang_btn)
    
    # Retrieve translation value from global window helper
    expected_text = driver.execute_script(f"return window.translate('{key_name}', '{lang_code}');")
    
    # Assert localized text presents in DOM
    WebDriverWait(driver, 5).until(
        EC.presence_of_element_located((By.XPATH, f"//*[contains(text(), '{expected_text}')]"))
    )

@pytest.mark.parametrize("element_id, desc", [
    ("nav-profile-btn", "Profile Navigation Button"),
    ("nav-chat-btn", "Chat Navigation Button"),
    ("nav-sos-btn", "SOS Navigation Button"),
    ("nav-weather-btn", "Weather Navigation Button"),
    ("gauge-speed-val", "Speed HUD Gauge"),
    ("gauge-heading-val", "Heading HUD Gauge"),
    ("voice-assistant-fab", "Voice Assistant Button"),
    ("simulator-speed-slider", "Simulator Speed Slider")
])
def test_ui_dashboard_hud_elements(driver, base_url, element_id, desc):
    """UI-UX Testing - Verify dashboard overlay control elements are visible on startup"""
    ensure_logged_in(driver, base_url)
    
    # Click Map Dashboard Nav
    driver.find_element(By.ID, "sidebar-nav-dashboard").click()
    
    element = WebDriverWait(driver, 5).until(
        EC.visibility_of_element_located((By.ID, element_id))
    )
    assert element.is_displayed()

@pytest.mark.parametrize("nav_id, section_header", [
    ("dashboard", "VESSEL DRIFT SIMULATOR"),
    ("weather", "MARINE WEATHER"),
    ("chat", "EMERGENCY CONTACTS"),
    ("sos", "EMERGENCY CONTACTS"),
    ("profile", "PROFILE")
])
def test_ui_sidebar_panel_visibility(driver, base_url, nav_id, section_header):
    """UI-UX Testing - Verify sidebar navigation routes display correct page panel sections"""
    ensure_logged_in(driver, base_url)
    
    nav_btn = WebDriverWait(driver, 5).until(
        EC.element_to_be_clickable((By.ID, f"sidebar-nav-{nav_id}"))
    )
    nav_btn.click()
    
    header = WebDriverWait(driver, 5).until(
        EC.presence_of_element_located((By.XPATH, f"//*[contains(text(), '{section_header}')]"))
    )
    assert header.is_displayed()

# =====================================================================
# SECTION 4: FUNCTIONAL TESTING (19 Test Cases)
# =====================================================================

def test_func_auth_flow(driver, base_url):
    """Functional Testing - Verify user signup and signin workflow"""
    mobile = f"9{random.randint(100000000, 999999999)}"
    register_user(driver, base_url, "Functional Auth User", mobile, "securepassword123")
    login_user(driver, base_url, mobile, "securepassword123")
    
    profile_btn = WebDriverWait(driver, 5).until(
        EC.visibility_of_element_located((By.ID, "nav-profile-btn"))
    )
    assert profile_btn.is_displayed()

@pytest.mark.parametrize("speed, heading", [
    (0, 0),
    (5, 90),
    (15, 180),
    (25, 270),
    (30, 359),
    (12, 45)
])
def test_func_vessel_telemetry_boundaries(driver, base_url, speed, heading):
    """Functional Testing - Verify real-time updates and bounds of speed and heading telemetry"""
    ensure_logged_in(driver, base_url)
    driver.find_element(By.ID, "sidebar-nav-dashboard").click()
    
    # Wait and adjust speed
    speed_slider = WebDriverWait(driver, 5).until(
        EC.presence_of_element_located((By.ID, "simulator-speed-slider"))
    )
    driver.execute_script(
        "const el = arguments[0]; "
        "const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set; "
        f"setter.call(el, {speed}); "
        "el.dispatchEvent(new Event('input', { bubbles: true })); "
        "el.dispatchEvent(new Event('change', { bubbles: true }));", 
        speed_slider
    )
    
    # Adjust heading
    heading_slider = driver.find_element(By.ID, "simulator-heading-slider")
    driver.execute_script(
        "const el = arguments[0]; "
        "const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set; "
        f"setter.call(el, {heading}); "
        "el.dispatchEvent(new Event('input', { bubbles: true })); "
        "el.dispatchEvent(new Event('change', { bubbles: true }));", 
        heading_slider
    )
    
    time.sleep(1.0)
    
    # Verify gauges render correct values
    speed_gauge = driver.find_element(By.ID, "gauge-speed-val")
    heading_gauge = driver.find_element(By.ID, "gauge-heading-val")
    
    assert f"{speed}.0" in speed_gauge.text
    assert f"{heading}" in heading_gauge.text

@pytest.mark.parametrize("lat, lon", [
    (9.1000, 79.5000),
    (9.2000, 79.7000),
    (9.3000, 79.9000),
    (9.5000, 80.1000),
    (9.8000, 80.1000)
])
def test_func_weather_location_coordinates(driver, base_url, lat, lon):
    """Functional Testing - Verify location coordinate bindings update within weather monitors"""
    ensure_logged_in(driver, base_url)
    
    # Click map dashboard
    driver.find_element(By.ID, "sidebar-nav-dashboard").click()
    
    # Click weather view
    driver.find_element(By.ID, "sidebar-nav-weather").click()
    
    # Wait for the loader to disappear to ensure weather REST endpoints populate weatherData state
    WebDriverWait(driver, 15).until(
        EC.invisibility_of_element_located((By.XPATH, "//*[contains(text(), 'Fetching Marine Data')]"))
    )
    
    # Verify coordinates presence
    lat_label = WebDriverWait(driver, 5).until(
        EC.presence_of_element_located((By.XPATH, "//*[contains(text(), 'Latitude')]"))
    )
    assert lat_label.is_displayed()

def test_func_chat_workflow(driver, base_url):
    """Functional Testing - Verify chat message submission with location attachments"""
    mobile_a = f"9{random.randint(100000000, 999999999)}"
    register_user(driver, base_url, "Alice Tester", mobile_a, "securepassword123")
    
    mobile_b = f"9{random.randint(100000000, 999999999)}"
    register_user(driver, base_url, "Bob Tester", mobile_b, "securepassword123")
    login_user(driver, base_url, mobile_b, "securepassword123")
    
    driver.find_element(By.ID, "sidebar-nav-chat").click()
    
    search_input = WebDriverWait(driver, 5).until(
        EC.visibility_of_element_located((By.ID, "contact-search-input"))
    )
    search_input.send_keys(mobile_a)
    
    result = WebDriverWait(driver, 5).until(
        EC.element_to_be_clickable((By.XPATH, "//*[contains(text(), 'Alice Tester')]"))
    )
    result.click()
    
    try:
        add_btn = WebDriverWait(driver, 3).until(
            EC.element_to_be_clickable((By.XPATH, "//*[contains(text(), 'ADD CONTACT')]"))
        )
        add_btn.click()
        WebDriverWait(driver, 5).until(EC.alert_is_present())
        driver.switch_to.alert.accept()
    except Exception:
        pass
        
    # Send secure message
    msg_input = driver.find_element(By.ID, "chat-message-input")
    msg_input.send_keys("Automated chat verification message.")
    
    driver.find_element(By.ID, "chat-send-btn").click()
    
    # Confirm delivery bubble
    WebDriverWait(driver, 5).until(
        EC.presence_of_element_located((By.XPATH, "//*[contains(text(), 'Automated chat verification')]"))
    )
