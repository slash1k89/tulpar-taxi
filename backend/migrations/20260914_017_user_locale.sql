ALTER TABLE users
  ADD COLUMN locale text NOT NULL DEFAULT 'ru'
  CONSTRAINT users_locale_supported CHECK (locale IN ('ru', 'kk', 'en'));
