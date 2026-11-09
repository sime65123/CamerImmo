# Configuration de l'authentification

L'app crée le compte avec email + mot de passe **sans confirmation par email**.
La certification (email, téléphone par SMS, CNI) se fait ensuite depuis
**Profil > Certifier mon compte**. Google et Apple sont proposés sur les
écrans de connexion et d'inscription.

Ces réglages se font dans les tableaux de bord, pas dans le code.

## 1. Supprimer la confirmation par email (obligatoire)
Supabase > Authentication > Providers > Email : désactiver **Confirm email**.
Sans ça, l'inscription affiche un message d'erreur explicite.

## 2. URLs de redirection
Supabase > Authentication > URL Configuration > Redirect URLs, ajouter :
- `camerimmo://login-callback` (mobile)
- `http://localhost:**` (développement web)

Le schéma `camerimmo://` est déclaré dans `AndroidManifest.xml` et `Info.plist`.

## 3. Google
1. Google Cloud Console > APIs & Services > Credentials > *OAuth client ID*,
   type **Web application**.
2. *Authorized redirect URI* :
   `https://wlchfwyipocgpvxjpxji.supabase.co/auth/v1/callback`
3. Copier Client ID et Client secret dans Supabase > Authentication >
   Providers > Google, puis activer.

## 4. Apple (iOS, macOS, web)
Demande un compte Apple Developer payant. Dans Apple Developer : créer un
*App ID* avec « Sign in with Apple », un *Services ID* (return URL =
`https://wlchfwyipocgpvxjpxji.supabase.co/auth/v1/callback`) et une *Key*
(.p8). Saisir Services ID, Team ID, Key ID et la clé dans Supabase >
Providers > Apple. Le bouton n'apparaît pas sur Android.

## 5. SMS (vérification du téléphone)
Supabase > Authentication > Providers > Phone : activer et renseigner Twilio.
Un compte Twilio **d'essai ne peut envoyer qu'aux numéros vérifiés** dans
Twilio : pour de vrais utilisateurs camerounais il faut un compte payant (ou
un autre fournisseur SMS supporté). Si l'envoi échoue, l'app affiche un
message et l'utilisateur peut certifier son numéro plus tard.

## 6. SQL
Exécuter dans l'ordre `supabase/migrations/001_lease_flow.sql` puis
`002_account_certification.sql`, puis `003_visits_maintenance.sql` (visites et maintenance). La 002 crée le bucket privé
`identity-documents` et empêche un utilisateur de se marquer lui-même comme
vérifié. Pour valider une CNI : mettre `cni_status = 'verified'` et
`cni_verified = true` sur son profil depuis le SQL Editor.
