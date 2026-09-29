(() => {
  const supported = ['ru', 'kk', 'en'];
  const stored = localStorage.getItem('tulpar-legal-locale');
  const browser = navigator.language.toLowerCase().split('-')[0];
  let current = supported.includes(stored) ? stored : (supported.includes(browser) ? browser : 'ru');
  const render = (locale) => {
    current = locale;
    localStorage.setItem('tulpar-legal-locale', locale);
    document.documentElement.lang = locale;
    document.querySelectorAll('[data-locale]').forEach((node) => {
      node.hidden = node.dataset.locale !== locale;
    });
    document.querySelectorAll('button[data-language]').forEach((button) => {
      button.setAttribute('aria-pressed', String(button.dataset.language === locale));
    });
  };
  document.querySelectorAll('button[data-language]').forEach((button) => {
    button.addEventListener('click', () => render(button.dataset.language));
  });
  render(current);
})();
