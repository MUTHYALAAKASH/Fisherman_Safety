{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.loadEntrypoint({
  onEntrypointLoaded: async function(engineInitializer) {
    let appRunner = await engineInitializer.initializeEngine({
      canvasKitBaseUrl: "canvaskit/"
    });
    appRunner.runApp();
  }
});
