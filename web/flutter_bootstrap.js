{{flutter_js}}
{{flutter_build_config}}

// Append cache-buster timestamp to mainJsPath so mobile browsers never reuse stale bytecode from disk
if (window._flutter && window._flutter.buildConfig && window._flutter.buildConfig.builds) {
  window._flutter.buildConfig.builds.forEach(function(b) {
    if (b.mainJsPath) {
      b.mainJsPath = b.mainJsPath + '?v=' + Date.now();
    }
  });
}

// Load Flutter without service worker to prevent stale caching
_flutter.loader.load();

