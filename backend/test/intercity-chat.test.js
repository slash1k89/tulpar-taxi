import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

import { intercityChatAccess } from '../src/routes/intercity-chat.js';

test('confirmed booking chat is writable for its participants', () => {
  assert.equal(intercityChatAccess({ booking_status: 'confirmed' }), 'write');
});

test('cancelled or missing booking has no chat access', () => {
  assert.equal(intercityChatAccess({ booking_status: 'cancelled' }), 'denied');
  assert.equal(intercityChatAccess(null), 'denied');
});

test('completed booking chat remains available for 24 hours only', () => {
  assert.equal(intercityChatAccess({
    booking_status: 'completed',
    completed_at: new Date(Date.now() - 23 * 60 * 60 * 1000),
  }), 'write');
  assert.equal(intercityChatAccess({
    booking_status: 'completed',
    completed_at: new Date(Date.now() - 25 * 60 * 60 * 1000),
  }), 'denied');
});

test('migration creates booking-scoped messages and reads without order chat reuse', async () => {
  const sql = await readFile(
    new URL('../migrations/20260921_020_intercity_booking_chat.sql', import.meta.url),
    'utf8',
  );
  assert.match(sql, /CREATE TABLE public\.intercity_booking_messages/);
  assert.match(sql, /booking_id uuid NOT NULL REFERENCES public\.intercity_ride_bookings/);
  assert.match(sql, /CREATE TABLE public\.intercity_booking_chat_reads/);
  assert.match(sql, /PRIMARY KEY \(booking_id, user_id\)/);
});
