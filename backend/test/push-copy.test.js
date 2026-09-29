import test from 'node:test';
import assert from 'node:assert/strict';

import { localizedPushCopy, normalizePushLocale } from '../src/push-copy.js';

test('background push uses the recipient locale for order and driver events', () => {
  assert.equal(localizedPushCopy({ eventType: 'accepted', locale: 'ru' }).body, 'Водитель принял ваш заказ.');
  assert.equal(localizedPushCopy({ eventType: 'accepted', locale: 'kk' }).body, 'Жүргізуші тапсырысыңызды қабылдады.');
  assert.equal(localizedPushCopy({ eventType: 'accepted', locale: 'en' }).body, 'A driver accepted your order.');
  assert.equal(localizedPushCopy({ eventType: 'new_driver_order', locale: 'kk' }).title, 'Жаңа тапсырыс');
});

test('missing or invalid locale falls back to Russian', () => {
  assert.equal(normalizePushLocale('fr'), 'ru');
  assert.equal(normalizePushLocale(null), 'ru');
  assert.equal(localizedPushCopy({ eventType: 'completed', locale: 'fr' }).title, 'Поездка завершена');
});

test('delivery and intercity copy use event parameters', () => {
  assert.equal(localizedPushCopy({ eventType: 'new_driver_order', locale: 'en', data: { serviceType: 'delivery' } }).title, 'New delivery');
  assert.equal(localizedPushCopy({ eventType: 'new_driver_order', locale: 'kk', data: { serviceType: 'intercity' } }).title, 'Жаңа қалааралық тапсырыс');
  assert.equal(localizedPushCopy({ eventType: 'accepted', locale: 'en', data: { serviceType: 'delivery' } }).title, 'Delivery accepted');
  assert.equal(localizedPushCopy({ eventType: 'intercity_ride_match_available', locale: 'en', data: { originCity: 'Astana', destinationCity: 'Esil' } }).body, 'A ride is available: Astana → Esil');
  assert.equal(localizedPushCopy({ eventType: 'intercity_ride_booked', locale: 'en', data: { seats: 1 } }).body, 'A passenger booked 1 seat');
  assert.equal(localizedPushCopy({ eventType: 'intercity_ride_booked', locale: 'en', data: { seats: 2 } }).body, 'A passenger booked 2 seats');
  assert.equal(localizedPushCopy({ eventType: 'intercity_ride_booked', locale: 'ru', data: { seats: 1 } }).body, 'Пассажир забронировал 1 место');
  assert.equal(localizedPushCopy({ eventType: 'intercity_ride_booked', locale: 'ru', data: { seats: 3 } }).body, 'Пассажир забронировал 3 места');
  assert.equal(localizedPushCopy({ eventType: 'intercity_ride_booked', locale: 'ru', data: { seats: 5 } }).body, 'Пассажир забронировал 5 мест');
});

test('message preview and unknown events preserve existing payload', () => {
  assert.deepEqual(localizedPushCopy({ eventType: 'chat_message', locale: 'en', fallbackBody: 'Hello' }), { title: 'New message', body: 'Hello' });
  assert.deepEqual(localizedPushCopy({ eventType: 'custom_event', locale: 'en', fallbackTitle: 'Title', fallbackBody: 'Body' }), { title: 'Title', body: 'Body' });
  assert.deepEqual(localizedPushCopy({ eventType: 'custom_event', locale: 'en' }), { title: 'MEKEN', body: '' });
});

test('intercity booking lifecycle and chat are localized for ru kk en', () => {
  for (const locale of ['ru', 'kk', 'en']) {
    for (const eventType of [
      'intercity_booking_created',
      'intercity_booking_cancelled',
      'intercity_trip_started',
      'intercity_trip_completed',
    ]) {
      const value = localizedPushCopy({ eventType, locale, data: { seats: 1 } });
      assert.ok(value.title.length > 0);
      assert.ok(value.body.length > 0);
    }
  }
  assert.deepEqual(
    localizedPushCopy({
      eventType: 'intercity_chat_message',
      locale: 'kk',
      data: { senderName: 'Айым', messagePreview: 'Сәлем' },
    }),
    { title: 'Айым', body: 'Сәлем' },
  );
});
