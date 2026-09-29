# MEKEN account deletion page — publication draft

Target URL: `https://tulpartaxi.kz/account-deletion`.

## Future web implementation contract

The page must work without redirecting the user back to the mobile app. It may
authenticate with the existing phone/password endpoint and call authenticated
`DELETE /api/account` with `{ "password": "<current password>" }`. It must show
the same active-order blockers and must never log the password or session token.
For a user who cannot sign in, the page must offer a support request through
`support@tulpartaxi.kz` with an operator-controlled ownership-verification procedure.
No public web page or support address has been deployed by this draft.

## Русский

Оператор сервиса MEKEN — ИП "Оспанов", индивидуальный предприниматель Махамбетов Нурлан Муратович, Республика Казахстан.

Чтобы удалить аккаунт MEKEN, откройте приложение, войдите в аккаунт и выберите
«Профиль / Настройки» → «Удалить аккаунт». Приложение попросит дважды подтвердить
действие и повторно ввести текущий пароль; Flash Call не требуется. Если есть активный заказ, поездка или бронирование, сначала
завершите или отмените его безопасным способом.

После подтверждения пароль, телефонная привязка, активные сессии и push-токены
удаляются, а номер телефона, имя, профиль водителя, адреса и лишние персональные
поля удаляются или необратимо обезличиваются. Текст отправленных сообщений
заменяется отметкой об удалении, комментарии к оценкам удаляются.
Необходимая история операций может сохраняться для безопасности, разрешения
споров и выполнения закона без лишних персональных идентификаторов.

Утверждённые сроки или критерии хранения: `<RETENTION_POLICY>`.

Если войти в приложение невозможно, отправьте запрос с адреса/канала, который
позволяет безопасно подтвердить владение аккаунтом: `support@tulpartaxi.kz`.

## Қазақша

MEKEN сервисінің операторы — ИП "Оспанов", жеке кәсіпкер Махамбетов Нурлан Муратович, Қазақстан Республикасы.

MEKEN аккаунтын жою үшін қосымшаға кіріп, «Профиль / Баптаулар» → «Аккаунтты
жою» тармағын таңдаңыз. Қосымша әрекетті және тұлғаңызды растауды сұрайды.
Қолданба ағымдағы құпиясөзді қайта енгізуді сұрайды; Flash Call қажет емес.
Белсенді тапсырыс, сапар немесе бронь болса, алдымен оны қауіпсіз аяқтаңыз не
болдырмаңыз.

Растаудан кейін белсенді сессиялар мен push-токендер жойылады, телефон нөмірі,
аты және артық жеке өрістер жойылады немесе қайтымсыз жасырындалады. Қауіпсіздік,
дауларды шешу және заң талаптары үшін қажетті операция тарихы артық жеке
идентификаторларсыз сақталуы мүмкін.

Бекітілген сақтау мерзімдері немесе өлшемдері: `<RETENTION_POLICY>`.

Қосымшаға кіру мүмкін болмаса, аккаунтқа иелікті қауіпсіз растауға болатын
арнадан сұрау жіберіңіз: `support@tulpartaxi.kz`.

## English

The operator of the MEKEN service is ИП "Оспанов", individual entrepreneur Махамбетов Нурлан Муратович, Republic of Kazakhstan.

To delete a MEKEN account, sign in to the app and choose Profile / Settings →
Delete account. The app asks you to confirm the action and your identity. If an
order, trip, or booking is active, complete or cancel it safely first.

The app requires the current password again; Flash Call is not required.
After confirmation, the password, phone identity, active sessions, and push
tokens are removed. The phone number, name, driver profile, route addresses,
and unnecessary personal fields are deleted or irreversibly
anonymized. Necessary transaction history may be retained without unnecessary
personal identifiers for safety, dispute resolution, and legal compliance.

Approved retention periods or criteria: `<RETENTION_POLICY>`.

If you cannot access the app, submit a request through a channel that allows
secure account-ownership verification: `support@tulpartaxi.kz`.
