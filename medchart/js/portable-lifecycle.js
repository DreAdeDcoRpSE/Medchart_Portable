/* Portable-only tab activity tracking. Every open tab has its own ID. */
(function () {
  'use strict';
  if (!window.crypto || !window.crypto.getRandomValues) return;
  var bytes = new Uint8Array(16);
  window.crypto.getRandomValues(bytes);
  var tabId = Array.prototype.map.call(bytes, function (b) { return ('0' + b.toString(16)).slice(-2); }).join('');
  function beat() {
    if (document.visibilityState === 'prerender') return;
    var body = new URLSearchParams();
    body.set('tab', tabId);
    fetch('/portable_heartbeat.php', {
      method: 'POST', body: body, credentials: 'same-origin',
      headers: { 'X-MedChart-Heartbeat': '1' }, cache: 'no-store',
      keepalive: true
    }).catch(function () {});
  }
  beat();
  window.setInterval(beat, 10000);
  document.addEventListener('visibilitychange', function () { if (!document.hidden) beat(); });
})();
