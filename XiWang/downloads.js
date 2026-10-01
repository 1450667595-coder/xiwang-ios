(() => {
  'use strict';
  const bridge = window.webkit?.messageHandlers?.xiwangDownload;
  if (!bridge) return;
  const originalClick = HTMLAnchorElement.prototype.click;
  async function exportBlob(anchor) {
    try {
      const response = await fetch(anchor.href);
      if (!response.ok) throw new Error('read');
      const blob = await response.blob();
      if (blob.size > 10_000_000) throw new Error('size');
      const base64 = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(String(reader.result).split(',')[1]);
        reader.onerror = reject;
        reader.readAsDataURL(blob);
      });
      bridge.postMessage({name: anchor.download, base64});
    } catch { bridge.postMessage({error: 'download'}); }
  }
  const isExport = anchor => anchor.download && anchor.href.startsWith('blob:') && /\.(json|html)$/i.test(anchor.download);
  HTMLAnchorElement.prototype.click = function () {
    if (isExport(this)) { void exportBlob(this); return; }
    originalClick.call(this);
  };
  document.addEventListener('click', event => {
    const anchor = event.target.closest?.('a[download]');
    if (anchor && isExport(anchor)) { event.preventDefault(); void exportBlob(anchor); }
  }, true);
})();
