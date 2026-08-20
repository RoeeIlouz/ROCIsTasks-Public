{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    renderer: "canvaskit",
  },
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    
    // Remove HTML splash screen just before drawing the first frame of the app
    const loadingDiv = document.getElementById("loading");
    if (loadingDiv) {
      loadingDiv.remove();
    }
    
    await appRunner.runApp();
  }
});
