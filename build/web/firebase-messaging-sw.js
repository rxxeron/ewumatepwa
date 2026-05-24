importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// Initialize Firebase with ewumatefcm credentials
firebase.initializeApp({
  apiKey: "AIzaSyCnFHdMw4PhHj81mY9gx2cqCDun5J-NCSo",
  authDomain: "ewumatefcm.firebaseapp.com",
  projectId: "ewumatefcm",
  storageBucket: "ewumatefcm.firebasestorage.app",
  messagingSenderId: "10908876468",
  appId: "1:10908876468:web:9c1a55780a9602961e1bb8"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Background message intercepted: ", payload);
  
  // Robust parsing to support both standard notification and data-only payloads safely
  const title = (payload.notification && payload.notification.title) || 
                (payload.data && payload.data.title) || 
                "EWUMate Notification";
                
  const body = (payload.notification && payload.notification.body) || 
               (payload.data && payload.data.body) || 
               "";
  
  const notificationOptions = {
    body: body,
    icon: "/icons/Icon-192.png",
    data: {
      url: (payload.data && payload.data.url) ? payload.data.url : "/"
    }
  };

  return self.registration.showNotification(title, notificationOptions);
});

// Navigate/focus standalone PWA window on click
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = (event.notification.data && event.notification.data.url) ? event.notification.data.url : "/";
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If a window is already open at the target URL, focus it
      for (const client of clientList) {
        if (client.url === targetUrl && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise, open a new window/tab
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
