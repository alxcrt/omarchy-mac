function notify(title, message) {
  chrome.notifications.create('', {
    type: 'basic',
    iconUrl: 'icon.png',
    title: title,
    message: String(message).slice(0, 200),
  }, () => { void chrome.runtime.lastError; });
}

function sendUrl(url) {
  if (!url || !/^https?:/i.test(url)) return;

  // Notify from Chrome itself. The native host's osascript notifications are
  // attributed to Script Editor, which needs its own notification permission
  // AND a Focus allow-list entry — so they silently vanish. Chrome is already
  // allowed to notify, so these actually show up.
  notify('Downloading…', url);

  chrome.runtime.sendNativeMessage('com.omarchy.ytdlp', { url }, (reply) => {
    if (chrome.runtime.lastError) {
      notify('Download failed', chrome.runtime.lastError.message || url);
      return;
    }
    if (reply && reply.ok === false) notify('Download failed', reply.error || url);
  });
}

function triggerDownload(tab) {
  if (!tab) return;

  // The activeTab permission exposes tab.url whenever the user invokes the
  // extension — both via the toolbar click and the keyboard shortcut.
  if (tab.url) {
    sendUrl(tab.url);
    return;
  }

  // Fallback: read the URL straight from the page.
  if (tab.id === undefined) return;
  chrome.scripting
    .executeScript({ target: { tabId: tab.id }, func: () => location.href })
    .then((results) => sendUrl(results && results[0] && results[0].result))
    .catch(() => {});
}

// Keyboard shortcut (Alt+Shift+D).
chrome.commands.onCommand.addListener((command) => {
  if (command === 'download-video') {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      triggerDownload(tabs[0]);
    });
  }
});

// Clicking the extension's toolbar icon.
chrome.action.onClicked.addListener((tab) => {
  triggerDownload(tab);
});
