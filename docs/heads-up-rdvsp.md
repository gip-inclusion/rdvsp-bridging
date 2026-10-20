# Note pour l’équipe RDV Service Public (à envoyer quand vous le souhaitez)

Bonjour,

Petit message pour vous prévenir d’une expérimentation qui utilise la synchronisation CalDAV de RDV Service Public,
sans modification de votre code.

**Contexte** : certains partenaires gèrent leur agenda dans un CRM (Pipedrive pour commencer, peut-être Salesforce
ensuite) et non dans un agenda CalDAV. Nous avons développé une petite passerelle, *rdvsp-bridging*, qui se présente à
RDV Service Public comme un serveur CalDAV : l’agent saisit l’URL, l’identifiant et le mot de passe fournis par la
passerelle dans « Synchronisation d’agenda → Connecter mon agenda via Caldav ».

**Ce que vous verrez** :

- des agents dont la configuration CalDAV pointe vers `https://<notre domaine>/caldav/<id>/calendar/` ;
- les requêtes habituelles de vos jobs `Caldav::ImportAbsencesFromCaldavJob` et `Caldav::ExportRdvToCaldavJob`.

**Ce que fait la passerelle** :

- elle expose les activités « occupées » du CRM comme des événements opaques (horaires seulement, titre « Occupé »,
  jamais de RRULE), avec un `sync-token` toujours valide (jamais d’erreur de token, pas de pagination 507) ;
- elle reçoit les RDV exportés (`PUT`/`DELETE`) et les recopie dans le CRM ; elle ne les ré-expose jamais comme
  occupations ; le test de connexion (`rdvsp-connection-test-*`) n’est pas transmis au CRM ;
- sans option explicite côté partenaire, rien qui identifie l’usager n’est transmis au CRM (et l’option
  « données sensibles » de l’agent reste conseillée désactivée).

Nous avons validé le fonctionnement avec la branche `production` (commit 8a20a75 du 14 octobre) : contrôle de
connexion, import incrémental, export, déplacement et annulation de RDV, calcul des créneaux.

**Ce qui nous aiderait** : être prévenus si le comportement du client CalDAV évolue (requêtes, filtres TRANSP/DTEND,
exigence du sync-token, éventuelle liste blanche de serveurs). Et si vous voyez des erreurs côté Sentry liées à notre
domaine, n’hésitez pas à nous écrire.

Merci !
