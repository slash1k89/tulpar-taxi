export function isLocalServiceType(serviceType) {
  return serviceType === 'city' || serviceType === 'delivery';
}

export function canReceiveLocalOrderNotification(order, driverWorkCity) {
  if (!isLocalServiceType(order?.serviceType)) return true;
  return typeof order?.cityId === 'string' &&
    order.cityId !== '' &&
    order.cityId === driverWorkCity;
}
