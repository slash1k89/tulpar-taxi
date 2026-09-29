export function chatRecipientUid(authenticatedUserId, order) {
  return authenticatedUserId === order.passenger_uid
    ? order.driver_uid
    : order.passenger_uid;
}

export function chatPushPayload({ senderName, text, orderId }) {
  return {
    title: String(senderName ?? '').trim() || 'Новое сообщение',
    body: text.length > 160 ? `${text.substring(0, 157)}...` : text,
    data: { type: 'chat_message', orderId },
  };
}
