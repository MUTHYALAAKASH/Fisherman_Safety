describe('Smart Fisherman Safety App Launch Test', () => {
    it('should successfully launch the application', async () => {
        // Wait 5 seconds for the app to settle
        await driver.pause(5000);
        
        // Fetch current active package name
        const currentPackage = await driver.getCurrentPackage();
        console.log(`Current active package: ${currentPackage}`);
        
        // Assert that the app package name matches fishermen_safety
        expect(currentPackage).toContain('fishermen_safety');

        // Take a startup screenshot to verify UI rendered correctly
        await driver.saveScreenshot('./screenshot_launch.png');
        console.log('Startup screenshot saved successfully to appium_tests/screenshot_launch.png!');
    });
});
