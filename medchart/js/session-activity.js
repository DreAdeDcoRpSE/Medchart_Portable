/* MedChart: keep an authenticated session active only while a person is using the page.
   The server retains its original 30-minute inactivity limit. */
(function () {
    'use strict';
    const token = document.querySelector('meta[name="medchart-csrf"]')?.content;
    if (!token) return;
    const endpoint = document.currentScript?.getAttribute('data-endpoint') || 'ajax/session_activity.php';
    const interval = 60 * 1000;
    let lastSent = Date.now(); // The page request already refreshed server activity.
    let sending = false;
    function userActivity(event) {
        if (event.type === 'keydown' && (event.ctrlKey || event.altKey || event.metaKey)) return;
        if (document.visibilityState === 'hidden' || sending || Date.now() - lastSent < interval) return;
        sending = true;
        // Native fetch avoids application-specific fetch wrappers and their error popups.
        window.fetch(endpoint, {
            method: 'POST', credentials: 'same-origin', cache: 'no-store',
            headers: { 'X-CSRF-Token': token },
            keepalive: false
        }).then(function (response) {
            if (response.ok) lastSent = Date.now();
            // On expiration do not silently reauthenticate or extend the session.
        }).catch(function () { /* A later real interaction can retry. */ })
          .finally(function () { sending = false; });
    }
    ['input', 'change', 'keydown', 'pointerdown'].forEach(function (type) {
        document.addEventListener(type, userActivity, { passive: true });
    });
})();
