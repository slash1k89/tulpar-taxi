const supportedLocales = new Set(['ru', 'kk', 'en']);

export function normalizePushLocale(locale) {
  return supportedLocales.has(locale) ? locale : 'ru';
}

function russianSeats(count) {
  const lastTwo = count % 100;
  if (lastTwo >= 11 && lastTwo <= 14) return 'мест';
  const last = count % 10;
  if (last === 1) return 'место';
  if (last >= 2 && last <= 4) return 'места';
  return 'мест';
}

const copy = {
  ru: {
    order_created: ['Новый заказ', 'Появился новый заказ.'],
    new_driver_order: ['Новый заказ', 'Появился новый заказ.'],
    order_accepted: ['Заказ принят', 'Водитель принял ваш заказ.'],
    offer_accepted: ['Предложение принято', 'Пассажир принял вашу цену.'],
    accepted: ['Заказ принят', 'Водитель принял ваш заказ.'],
    driver_heading_to_pickup: ['Водитель едет к вам', 'Водитель направляется к месту подачи.'],
    driver_approaching_pickup: ['Водитель скоро будет на месте', 'Пожалуйста, выходите к месту подачи — водитель уже подъезжает.'],
    driver_arrived: ['Водитель на месте', 'Машина ожидает вас. Выходите к месту посадки.'],
    arrived: ['Водитель на месте', 'Машина ожидает вас. Выходите к месту посадки.'],
    in_progress: ['Поездка началась', 'Вы в пути.'],
    completed: ['Поездка завершена', 'Спасибо за поездку!'],
    cancelled: ['Заказ отменён', 'Заказ был отменён.'],
    city_cancelled_by_passenger: ['Заказ отменён пассажиром', 'Пассажир отменил поездку.'],
    city_cancelled_by_driver: ['Водитель отменил поездку', 'Поездка отменена водителем.'],
    chat_message: ['Новое сообщение', 'У вас новое сообщение.'],
    intercity_ride_match_available: ['Новая попутка', 'Появилась подходящая попутка.'],
    intercity_booking_cancelled: ['Бронирование отменено', 'Пассажир отменил бронирование.'],
    intercity_booking_created: ['Новая бронь', 'Пассажир забронировал место в вашей поездке.'],
    intercity_ride_booked: ['Новое бронирование', 'Пассажир забронировал места.'],
    intercity_ride_cancelled: ['Попутка отменена', 'Водитель отменил попутку.'],
    intercity_ride_departed: ['Попутка отправилась', 'Поездка началась.'],
    intercity_trip_started: ['Поездка началась', 'Междугородняя поездка отправилась.'],
    intercity_trip_completed: ['Поездка завершена', 'Междугородняя поездка завершена.'],
    intercity_chat_message: ['Новое сообщение', 'У вас новое сообщение по междугородней поездке.'],
    delivery_created: ['Новая доставка', 'Появился новый заказ на доставку.'],
    intercity_created: ['Новый межгород', 'Появился новый междугородний заказ.'],
    delivery_accepted: ['Доставка принята', 'Курьер принял ваш заказ.'],
    delivery_completed: ['Доставка завершена', 'Посылка доставлена.'],
  },
  kk: {
    order_created: ['Жаңа тапсырыс', 'Жаңа тапсырыс түсті.'],
    new_driver_order: ['Жаңа тапсырыс', 'Жаңа тапсырыс түсті.'],
    order_accepted: ['Тапсырыс қабылданды', 'Жүргізуші тапсырысыңызды қабылдады.'],
    offer_accepted: ['Ұсыныс қабылданды', 'Жолаушы сіздің бағаңызды қабылдады.'],
    accepted: ['Тапсырыс қабылданды', 'Жүргізуші тапсырысыңызды қабылдады.'],
    driver_heading_to_pickup: ['Жүргізуші келе жатыр', 'Жүргізуші сізге қарай жолға шықты.'],
    driver_approaching_pickup: ['Жүргізуші жақындап қалды', 'Шығуға дайындалыңыз — жүргізуші келіп қалды.'],
    driver_arrived: ['Жүргізуші келді', 'Жүргізуші жетіп, сізді күтіп тұр.'],
    arrived: ['Жүргізуші келді', 'Жүргізуші жетіп, сізді күтіп тұр.'],
    in_progress: ['Сапар басталды', 'Сіз жолдасыз.'],
    completed: ['Сапар аяқталды', 'Сапарыңыз үшін рақмет!'],
    cancelled: ['Тапсырыс тоқтатылды', 'Тапсырыс тоқтатылды.'],
    city_cancelled_by_passenger: ['Тапсырысты жолаушы тоқтатты', 'Жолаушы сапарды тоқтатты.'],
    city_cancelled_by_driver: ['Жүргізуші сапарды тоқтатты', 'Сапарды жүргізуші тоқтатты.'],
    chat_message: ['Жаңа хабарлама', 'Сізге жаңа хабарлама келді.'],
    intercity_ride_match_available: ['Жаңа сапар', 'Сізге қолайлы қалааралық сапар табылды.'],
    intercity_booking_cancelled: ['Бронь тоқтатылды', 'Жолаушы броньды тоқтатты.'],
    intercity_booking_created: ['Жаңа бронь', 'Жолаушы сіздің сапарыңызға орын броньдады.'],
    intercity_ride_booked: ['Жаңа бронь', 'Жолаушы орындарды броньдады.'],
    intercity_ride_cancelled: ['Сапар тоқтатылды', 'Жүргізуші қалааралық сапарды тоқтатты.'],
    intercity_ride_departed: ['Сапар басталды', 'Қалааралық сапар басталды.'],
    intercity_trip_started: ['Сапар басталды', 'Қалааралық сапар жолға шықты.'],
    intercity_trip_completed: ['Сапар аяқталды', 'Қалааралық сапар аяқталды.'],
    intercity_chat_message: ['Жаңа хабарлама', 'Қалааралық сапар бойынша жаңа хабарлама келді.'],
    delivery_created: ['Жаңа жеткізу тапсырысы', 'Жаңа жеткізу тапсырысы түсті.'],
    intercity_created: ['Жаңа қалааралық тапсырыс', 'Жаңа қалааралық тапсырыс түсті.'],
    delivery_accepted: ['Жеткізу қабылданды', 'Курьер тапсырысыңызды қабылдады.'],
    delivery_completed: ['Жеткізу аяқталды', 'Сәлемдеме жеткізілді.'],
  },
  en: {
    order_created: ['New order', 'A new order is available.'],
    new_driver_order: ['New order', 'A new order is available.'],
    order_accepted: ['Order accepted', 'A driver accepted your order.'],
    offer_accepted: ['Offer accepted', 'The passenger accepted your price.'],
    accepted: ['Order accepted', 'A driver accepted your order.'],
    driver_heading_to_pickup: ['Driver on the way', 'Your driver is heading to the pickup point.'],
    driver_approaching_pickup: ['Driver almost there', 'Please head to the pickup point — your driver is approaching.'],
    driver_arrived: ['Driver arrived', 'Your driver is waiting at the pickup point.'],
    arrived: ['Driver arrived', 'Your driver is waiting at the pickup point.'],
    in_progress: ['Trip started', 'You are on your way.'],
    completed: ['Trip completed', 'Thanks for riding with us!'],
    cancelled: ['Order cancelled', 'The order was cancelled.'],
    city_cancelled_by_passenger: ['Order cancelled by passenger', 'The passenger cancelled the trip.'],
    city_cancelled_by_driver: ['Driver cancelled the trip', 'The driver cancelled the trip.'],
    chat_message: ['New message', 'You have a new message.'],
    intercity_ride_match_available: ['New ride', 'A matching intercity ride is available.'],
    intercity_booking_cancelled: ['Booking cancelled', 'A passenger cancelled their booking.'],
    intercity_booking_created: ['New booking', 'A passenger booked a seat on your ride.'],
    intercity_ride_booked: ['New booking', 'A passenger booked seats.'],
    intercity_ride_cancelled: ['Ride cancelled', 'The driver cancelled the intercity ride.'],
    intercity_ride_departed: ['Ride departed', 'The intercity ride has started.'],
    intercity_trip_started: ['Ride started', 'The intercity ride has departed.'],
    intercity_trip_completed: ['Ride completed', 'The intercity ride is complete.'],
    intercity_chat_message: ['New message', 'You have a new intercity ride message.'],
    delivery_created: ['New delivery', 'A new delivery order is available.'],
    intercity_created: ['New intercity order', 'A new intercity order is available.'],
    delivery_accepted: ['Delivery accepted', 'A courier accepted your order.'],
    delivery_completed: ['Delivery completed', 'Your package was delivered.'],
  },
};

export function localizedPushCopy({ eventType, locale, data = {}, fallbackTitle = 'MEKEN', fallbackBody = '' }) {
  const language = normalizePushLocale(locale);
  const serviceType = data.serviceType?.toString();
  const serviceEvent = serviceType === 'delivery'
    ? { order_created: 'delivery_created', new_driver_order: 'delivery_created', accepted: 'delivery_accepted', completed: 'delivery_completed' }[eventType]
    : serviceType === 'intercity'
      ? { order_created: 'intercity_created', new_driver_order: 'intercity_created' }[eventType]
      : null;
  const cityCancellationEvent = serviceType === 'city' && eventType === 'cancelled'
    && ['passenger', 'driver'].includes(data.cancelledBy)
    ? `city_cancelled_by_${data.cancelledBy}` : null;
  const pair = copy[language][cityCancellationEvent ?? serviceEvent ?? eventType];
  if (!pair) return { title: fallbackTitle, body: fallbackBody };
  let body = pair[1];
  if (eventType === 'chat_message' && fallbackBody) body = fallbackBody;
  if (eventType === 'intercity_ride_match_available' && data.originCity && data.destinationCity) {
    body = language === 'ru'
      ? `Появилась попутка ${data.originCity} → ${data.destinationCity}`
      : language === 'kk'
        ? `${data.originCity} → ${data.destinationCity} бағыты бойынша сапар табылды`
        : `A ride is available: ${data.originCity} → ${data.destinationCity}`;
  }
  if ((eventType === 'intercity_ride_booked' || eventType === 'intercity_booking_created') && Number.isInteger(Number(data.seats))) {
    const seats = Number(data.seats);
    body = language === 'ru'
      ? `Пассажир забронировал ${seats} ${russianSeats(seats)}`
      : language === 'kk'
        ? `Жолаушы ${seats} орынды броньдады`
        : `A passenger booked ${seats} ${seats === 1 ? 'seat' : 'seats'}`;
  }
  if (eventType === 'intercity_chat_message' && data.messagePreview) {
    return {
      title: String(data.senderName || pair[0]).trim() || pair[0],
      body: String(data.messagePreview),
    };
  }
  return { title: pair[0], body };
}
