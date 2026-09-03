// Keep this version aligned with firebase_core_web's
// supportedFirebaseJsSdkVersion in pubspec.lock.
importScripts(
  'https://www.gstatic.com/firebasejs/12.17.0/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/12.17.0/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyDG2m30Q9BzBEXxA9Rb9NAWj9Lid-JVSIw',
  authDomain: 'taxi-esil.firebaseapp.com',
  projectId: 'taxi-esil',
  storageBucket: 'taxi-esil.firebasestorage.app',
  messagingSenderId: '416483778124',
  appId: '1:416483778124:web:b3d88d9cdc52f1daa41ee9',
  measurementId: 'G-9PKB69CTPR',
});

// Creating the instance enables Firebase Messaging background handling.
const messaging = firebase.messaging();
