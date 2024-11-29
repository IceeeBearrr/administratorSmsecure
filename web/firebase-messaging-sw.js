importScripts('https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js');

firebase.initializeApp({
    // Your Firebase config object
    apiKey: "AIzaSyCvfFNl0PYO2m5cPEpBw6H4aELvueCwGLA",
    authDomain: "sm-9ca41.firebaseapp.com",
    projectId: "smsecure",
    storageBucket: "smsecure.firebasestorage.app",
    messagingSenderId: "845609608653",
    appId: "1:845609608653:web:b57358f933fa17107f9084",
    measurementId: "G-W6FH2ZCH19"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
    console.log('Received background message:', payload);

    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/images/smsecureIcon.jpg'
    };

    return self.registration.showNotification(notificationTitle, notificationOptions);
});