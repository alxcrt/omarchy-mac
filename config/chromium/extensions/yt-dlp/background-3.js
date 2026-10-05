// Keep this filename versioned. Chromium caches service workers for extensions
// loaded via --load-extension, so a new URL forces registration of new code.
//
// Chrome shows only the live progress (notification + toolbar badge). The
// outcome comes from webdl itself (mac-notify): "Download complete" there is
// clickable to copy a share-ready file, so a second Chrome notification would
// only duplicate it. Chrome reports a failure only when the native host could
// not run at all, since webdl never got the chance to.

const HOST = 'com.omarchy.ytdlp';
const PROGRESS_ID = 'ytdlp-progress';

function notify(id, options) {
  chrome.notifications.create(id, {
    type: 'basic',
    iconUrl: 'icon.png',
    title: 'Download Video',
    ...options,
    message: String(options.message || '').slice(0, 200),
  }, () => { void chrome.runtime.lastError; });
}

function badge(text) {
  chrome.action.setBadgeText({ text });
  if (text) chrome.action.setBadgeBackgroundColor({ color: '#1a73e8' });
}

function download(url) {
  if (!url || !/^https?:/i.test(url)) return;

  notify(PROGRESS_ID, { title: 'Downloading…', message: url });
  badge('…');

  // A long-lived port, not sendNativeMessage: the host streams progress lines
  // while yt-dlp runs, which a one-shot request can't express.
  const port = chrome.runtime.connectNative(HOST);
  let shown = -1;

  port.onMessage.addListener((msg) => {
    if (typeof msg.progress === 'number') {
      const pct = Math.round(msg.progress);
      badge(`${pct}%`);
      // ponytail: throttled to 5% steps so macOS doesn't re-banner every tick.
      // The badge is the live number; drop this update if it still feels noisy.
      if (pct >= shown + 5) {
        shown = pct;
        chrome.notifications.update(PROGRESS_ID, {
          title: `Downloading… ${pct}%`,
          message: url,
        }, () => { void chrome.runtime.lastError; });
      }
      return;
    }

    // Done or failed: webdl has already posted the outcome.
    chrome.notifications.clear(PROGRESS_ID);
    badge('');
    port.disconnect();
  });

  port.onDisconnect.addListener(() => {
    badge('');
    if (chrome.runtime.lastError) {
      chrome.notifications.clear(PROGRESS_ID);
      notify('', { title: 'Download failed', message: chrome.runtime.lastError.message });
    }
  });

  port.postMessage({ url });
}

function triggerDownload(tab) {
  if (!tab) return;

  // activeTab exposes tab.url whenever the user invokes the extension — both
  // via the toolbar click and the keyboard shortcut.
  if (tab.url) {
    download(tab.url);
    return;
  }
  if (tab.id === undefined) return;
  chrome.scripting
    .executeScript({ target: { tabId: tab.id }, func: () => location.href })
    .then((results) => download(results && results[0] && results[0].result))
    .catch(() => {});
}

chrome.commands.onCommand.addListener((command) => {
  if (command !== 'download-video') return;
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => triggerDownload(tabs[0]));
});

chrome.action.onClicked.addListener((tab) => triggerDownload(tab));
