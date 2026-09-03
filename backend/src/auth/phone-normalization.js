export function normalizeKazakhstanPhone(value) {
  if (typeof value !== 'string') {
    throw new Error('Invalid Kazakhstan phone number');
  }
  const input = value.trim();
  if (input.length === 0 || !/^[+\d\s()-]+$/.test(input)) {
    throw new Error('Invalid Kazakhstan phone number');
  }
  let digits = input.replace(/\D/g, '');
  if (digits.length !== 11 || !['7', '8'].includes(digits[0])) {
    throw new Error('Invalid Kazakhstan phone number');
  }
  if (digits[0] === '8') digits = `7${digits.slice(1)}`;
  if (!['6', '7'].includes(digits[1])) {
    throw new Error('Invalid Kazakhstan phone number');
  }
  return `+${digits}`;
}
