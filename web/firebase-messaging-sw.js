importScripts("https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js");

// Forzar activación inmediata
self.addEventListener('install', (event) => { self.skipWaiting(); });
self.addEventListener('activate', (event) => { event.waitUntil(clients.claim()); });

firebase.initializeApp({
  apiKey: "AIzaSyBM8jTTIMo4ZiSURb_1Hq4Fa9Vmid93XFo",
  authDomain: "campus-baloncesto.firebaseapp.com",
  projectId: "campus-baloncesto",
  storageBucket: "campus-baloncesto.firebasestorage.app",
  messagingSenderId: "712402576575",
  appId: "1:712402576575:web:c3a6deef59f85277d1520a",
  measurementId: "G-2NWLTF05JM"
});

const messaging = firebase.messaging();

// Usar onBackgroundMessage para mostrar NUESTRA notificación personalizada
messaging.onBackgroundMessage((payload) => {
  console.log("[SW] Background message:", payload);

  const title = payload.notification?.title || payload.data?.title || "Nuevo Aviso";
  const body = payload.notification?.body || payload.data?.body || "";

  // Cerrar la notificación automática de FCM (si la hay) y reemplazar con la nuestra
  return self.registration.getNotifications({ tag: '' }).then((notifications) => {
    // Cerrar notificaciones sin nuestro tag
    notifications.forEach(n => {
      if (n.tag !== 'campus-aviso') n.close();
    });

    return self.registration.showNotification(title, {
      body: body,
      icon: "/icons/Icon-192.png",
      badge: "/icons/Icon-192.png",
      tag: "campus-aviso",
      renotify: true,
      data: { url: payload.data?.url || self.location.origin }
    });
  });
});

// Al pulsar la notificación, abrir o enfocar la app en el home o url correspondiente
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  
  // Obtener URL de destino, asegurar prefijo /#/ si es relativa
  let targetUrl = event.notification.data?.url || self.location.origin;
  if (!targetUrl.includes('/#/')) {
    targetUrl = self.location.origin + '/#/';
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      return clients.openWindow(targetUrl);
    })
  );
});
