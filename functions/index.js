const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

/**
 * Sends FCM when a new message is created.
 * Deploy: firebase deploy --only functions
 * Requires Blaze plan for Cloud Functions.
 */
exports.onNewMessage = onDocumentCreated(
  'chats/{chatId}/messages/{messageId}',
  async (event) => {
    const message = event.data.data();
    const chatId = event.params.chatId;
    const senderId = message.senderId;

    const chatSnap = await getFirestore().doc(`chats/${chatId}`).get();
    if (!chatSnap.exists) return;

    const chat = chatSnap.data();
    const participants = chat.participants || [];
    const mutedBy = chat.mutedBy || [];

    const recipients = participants.filter(
      (uid) => uid !== senderId && !mutedBy.includes(uid),
    );

    for (const uid of recipients) {
      const userSnap = await getFirestore().doc(`users/${uid}`).get();
      const tokens = userSnap.data()?.fcmTokens || [];
      if (!tokens.length) continue;

      const title = message.senderName || 'New message';
      const body =
        message.type === 'text'
          ? message.content
          : `Sent a ${message.type}`;

      await getMessaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: {
          chatId,
          type: 'new_message',
        },
        android: { priority: 'high' },
      });
    }
  },
);
