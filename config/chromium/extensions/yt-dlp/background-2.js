// Keep this filename versioned. Chromium caches service workers for extensions
// loaded via --load-extension, so a new URL forces registration of new code.
//
// Notifications come from Chrome, never from the native host: the host's
// osascript notifications are attributed to Script Editor, which needs its own
// notification permission AND a Focus allow-list entry, so they silently vanish.

const HOST = 'com.omarchy.ytdlp';
const PROGRESS_ID = 'ytdlp-progress';

// The finished file's path is carried in the notification id, so clicks still
// work after the service worker has been torn down and restarted.
const DONE_PREFIX = 'ytdlp-done:';

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

function ask(action, path, text) {
  chrome.runtime.sendNativeMessage(HOST, { action, path, text }, () => {
    void chrome.runtime.lastError;
  });
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

    chrome.notifications.clear(PROGRESS_ID);
    badge('');

    if (msg.done) {
      notify(DONE_PREFIX + msg.path, {
        title: 'Download complete',
        message: msg.name || msg.path,
        buttons: [{ title: 'Show in Finder' }, { title: 'Copy path' }],
      });
    } else {
      notify('', { title: 'Download failed', message: msg.error || url });
    }
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

// Click the finished notification to play the file; buttons reveal it or copy
// its path. Everything runs through the native host — the extension itself
// cannot touch the filesystem or the clipboard from a service worker.
chrome.notifications.onClicked.addListener((id) => {
  if (id.startsWith(DONE_PREFIX)) ask('open', id.slice(DONE_PREFIX.length));
  chrome.notifications.clear(id);
});

chrome.notifications.onButtonClicked.addListener((id, button) => {
  if (!id.startsWith(DONE_PREFIX)) return;
  const path = id.slice(DONE_PREFIX.length);
  ask(button === 0 ? 'reveal' : 'copy', path);
  chrome.notifications.clear(id);
});

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
