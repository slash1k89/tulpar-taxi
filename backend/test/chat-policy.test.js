import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

import { chatPushPayload, chatRecipientUid } from '../src/chat-policy.js';

const order = { passenger_uid: 'passenger', driver_uid: 'driver' };

test('chat push is addressed only to the other order participant', () => {
  assert.equal(chatRecipientUid('passenger', order), 'driver');
  assert.equal(chatRecipientUid('driver', order), 'passenger');
});

test('chat background payload has clear copy, sound-compatible notification and route data', () => {
  assert.deepEqual(chatPushPayload({
    senderName: 'Айбек', text: 'Я на месте', orderId: 'order-1',
  }), {
    title: 'Айбек',
    body: 'Я на месте',
    data: { type: 'chat_message', orderId: 'order-1' },
  });
});

test('unread state is persisted and exposed through read/count endpoints', async () => {
  const [migration, server, unreadRoutes] = await Promise.all([
    readFile(new URL('../migrations/20260907_016_chat_read_state.sql', import.meta.url), 'utf8'),
    readFile(new URL('../src/server.js', import.meta.url), 'utf8'),
    readFile(new URL('../src/routes/chat-unread.js', import.meta.url), 'utf8'),
  ]);
  assert.match(migration, /CREATE TABLE public\.order_chat_reads/);
  assert.match(migration, /PRIMARY KEY \(order_id, user_id\)/);
  assert.match(server, /createChatUnreadRouter/);
  assert.match(server, /markChatRead/);
  assert.match(unreadRoutes, /router\.get\('\/unread'/);
  assert.match(unreadRoutes, /router\.post\('\/read'/);
  assert.match(unreadRoutes, /DO UPDATE SET last_read_at/);
  assert.match(unreadRoutes, /m\.sender_id <> viewer\.id/);
});
