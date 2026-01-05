/**
 * Unity WebGL Loader with loading spinner
 * Usage: loadUnityGame("#canvas-id", "Build", { name: "BuildName" })
 */
function loadUnityGame(canvasSelector, buildPath, config = {}) {
  const canvas = document.querySelector(canvasSelector);
  if (!canvas) {
    console.error("Canvas not found:", canvasSelector);
    return Promise.reject("Canvas not found");
  }

  // Create overlay dynamically
  const overlay = document.createElement("div");
  overlay.id = "loading-overlay";
  overlay.innerHTML = `
    <div class="unity-spinner"></div>
    <div class="unity-loading-text">Loading... 0%</div>
  `;
  document.body.prepend(overlay);

  // Inject styles once
  if (!document.getElementById("unity-loader-styles")) {
    const style = document.createElement("style");
    style.id = "unity-loader-styles";
    style.textContent = `
      #loading-overlay {
        position: fixed;
        inset: 0;
        background: #231F20;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        z-index: 10;
      }
      .unity-spinner {
        width: 50px;
        height: 50px;
        border: 4px solid #444;
        border-top-color: #22d3ee;
        border-radius: 50%;
        animation: unity-spin 1s linear infinite;
      }
      @keyframes unity-spin {
        to { transform: rotate(360deg); }
      }
      .unity-loading-text {
        color: #ccc;
        margin-top: 16px;
        font-family: sans-serif;
        font-size: 14px;
      }
    `;
    document.head.appendChild(style);
  }

  const textEl = overlay.querySelector(".unity-loading-text");
  const buildName = config.name || "Build";

  // Mobile detection and canvas adjustment
  if (/iPhone|iPad|iPod|Android/i.test(navigator.userAgent)) {
    let meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement("meta");
      meta.name = "viewport";
      document.head.appendChild(meta);
    }
    meta.content =
      "width=device-width, height=device-height, initial-scale=1.0, user-scalable=no, shrink-to-fit=yes";

    canvas.style.width = "100%";
    canvas.style.height = "100%";
    canvas.style.position = "fixed";
    document.body.style.textAlign = "left";
  }

  // Build Unity config
  const unityConfig = {
    dataUrl: `${buildPath}/${buildName}.data`,
    frameworkUrl: `${buildPath}/${buildName}.framework.js`,
    codeUrl: `${buildPath}/${buildName}.wasm`,
    streamingAssetsUrl: config.streamingAssetsUrl || "StreamingAssets",
    companyName: config.companyName || "",
    productName: config.productName || "",
    productVersion: config.productVersion || "1.0",
    ...config.extra,
  };

  return createUnityInstance(
    canvas,
    unityConfig,
    (progress) => {
      textEl.textContent = `Loading... ${Math.round(progress * 100)}%`;
    }
  )
    .then((unityInstance) => {
      overlay.remove();
      return unityInstance;
    })
    .catch((error) => {
      textEl.textContent = `Error: ${error}`;
      throw error;
    });
}
