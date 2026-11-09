import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../home/home_screen.dart' show userProfileProvider;

/// Carte « Certifier mon compte » du profil.
///
/// Rien n'est obligatoire : on peut utiliser l'app dès l'inscription et
/// certifier son compte plus tard (email, téléphone par SMS, CNI).
class AccountCertificationCard extends ConsumerWidget {
  final Map<String, dynamic> profile;
  const AccountCertificationCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final emailOk = user?.emailConfirmedAt != null;
    final phoneOk = user?.phoneConfirmedAt != null;
    final cniStatus = _cniStatus(profile);
    final cniOk = cniStatus == 'verified';
    final done = [emailOk, phoneOk, cniOk].where((e) => e).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Certifier mon compte',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: done == 3
                      ? AppColors.successLight
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$done/3',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: done == 3 ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Un compte certifié inspire confiance aux bailleurs et aux locataires.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: done / 3,
              minHeight: 8,
              backgroundColor: AppColors.borderLight,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          _StepRow(
            icon: Icons.mail_outline,
            title: 'Adresse email',
            subtitle: user?.email ?? 'Non renseignée',
            done: emailOk,
            actionLabel: 'Renvoyer le lien',
            onAction: () => _resendEmail(context),
          ),
          _StepRow(
            icon: Icons.phone_outlined,
            title: 'Numéro de téléphone',
            subtitle: (profile['phone'] as String?)?.isNotEmpty == true
                ? profile['phone'] as String
                : 'Non renseigné',
            done: phoneOk,
            actionLabel: 'Vérifier par SMS',
            onAction: () => showPhoneVerifySheet(context,
                initialPhone: profile['phone'] as String?),
          ),
          _StepRow(
            icon: Icons.badge_outlined,
            title: 'Carte nationale d\'identité',
            subtitle: switch (cniStatus) {
              'verified' => 'Vérifiée',
              'pending' => 'En cours de vérification',
              'rejected' => 'Refusée — renvoyez des photos lisibles',
              _ => 'Non envoyée',
            },
            done: cniOk,
            pending: cniStatus == 'pending',
            actionLabel: cniStatus == 'rejected' ? 'Renvoyer' : 'Envoyer',
            onAction: cniStatus == 'pending' || cniOk
                ? null
                : () => showCniVerifySheet(context),
          ),
        ],
      ),
    );
  }

  static String _cniStatus(Map<String, dynamic> p) {
    if (p['cni_verified'] == true) return 'verified';
    return (p['cni_status'] as String?) ?? 'none';
  }

  Future<void> _resendEmail(BuildContext context) async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return;
    try {
      await Supabase.instance.client.auth
          .resend(type: OtpType.signup, email: email);
      if (context.mounted) _toast(context, 'Lien envoyé à $email');
    } on AuthException catch (e) {
      debugPrint('Resend email error: ${e.message}');
      if (context.mounted) {
        _toast(context, 'Envoi impossible pour le moment. Réessayez plus tard.',
            error: true);
      }
    }
  }
}

void _toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white)),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );
}

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final bool pending;
  final String actionLabel;
  final VoidCallback? onAction;

  const _StepRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.actionLabel,
    required this.onAction,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.success
        : pending
            ? AppColors.warning
            : AppColors.textTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(done ? Icons.check_rounded : icon,
                color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    )),
              ],
            ),
          ),
          if (!done && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  )),
            ),
        ],
      ),
    );
  }
}

// ─── Vérification du téléphone par SMS ───────────────────────────────────────

void showPhoneVerifySheet(BuildContext context, {String? initialPhone}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PhoneVerifySheet(initialPhone: initialPhone),
  );
}

class _PhoneVerifySheet extends ConsumerStatefulWidget {
  final String? initialPhone;
  const _PhoneVerifySheet({this.initialPhone});

  @override
  ConsumerState<_PhoneVerifySheet> createState() => _PhoneVerifySheetState();
}

class _PhoneVerifySheetState extends ConsumerState<_PhoneVerifySheet> {
  late final TextEditingController _phoneCtrl;
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// +237 par défaut si l'utilisateur tape un numéro local.
  String get _phone {
    final raw = _phoneCtrl.text.replaceAll(RegExp(r'[\s\-().]'), '');
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('00')) return '+${raw.substring(2)}';
    return '${AppConstants.phonePrefix}$raw';
  }

  Future<void> _sendCode() async {
    if (_phoneCtrl.text.trim().length < 8) {
      setState(() => _error = 'Entrez un numéro valide.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(phone: _phone));
      if (mounted) setState(() => _codeSent = true);
    } on AuthException catch (e) {
      debugPrint('Send SMS error: ${e.message}');
      if (mounted) {
        setState(() => _error =
            'L\'envoi du SMS a échoué. Vous pourrez certifier votre numéro plus tard.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Entrez le code reçu par SMS.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        phone: _phone,
        token: code,
        type: OtpType.phoneChange,
      );
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'phone': _phone}).eq('id', uid);
      }
      ref.invalidate(userProfileProvider);
      if (mounted) {
        Navigator.pop(context);
        _toast(context, 'Numéro certifié');
      }
    } on AuthException catch (e) {
      debugPrint('Verify SMS error: ${e.message}');
      if (mounted) {
        setState(() => _error = 'Code incorrect ou expiré.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Vérifier mon numéro',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 6),
          Text(
            _codeSent
                ? 'Un code a été envoyé au $_phone.'
                : 'Nous vous envoyons un code par SMS.',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          if (!_codeSent)
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Téléphone',
                hintText: '6XX XXX XXX',
                prefixText: '${AppConstants.phonePrefix} ',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            )
          else
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 20, letterSpacing: 6),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '------',
                counterText: '',
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.error,
                )),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      _codeSent ? 'Valider le code' : 'Envoyer le code',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          if (_codeSent)
            Center(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _codeSent = false;
                          _codeCtrl.clear();
                          _error = null;
                        }),
                child: const Text('Changer de numéro',
                    style: TextStyle(
                        fontFamily: 'Poppins', color: AppColors.primary)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Envoi de la CNI ─────────────────────────────────────────────────────────

void showCniVerifySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _CniVerifySheet(),
  );
}

class _CniVerifySheet extends ConsumerStatefulWidget {
  const _CniVerifySheet();

  @override
  ConsumerState<_CniVerifySheet> createState() => _CniVerifySheetState();
}

class _CniVerifySheetState extends ConsumerState<_CniVerifySheet> {
  Uint8List? _recto;
  Uint8List? _verso;
  bool _busy = false;
  String? _error;

  Future<void> _pick(bool recto) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() => recto ? _recto = bytes : _verso = bytes);
  }

  Future<void> _submit() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || _recto == null || _verso == null) {
      setState(() => _error = 'Ajoutez le recto et le verso.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final storage =
          Supabase.instance.client.storage.from('identity-documents');
      const opts = FileOptions(contentType: 'image/jpeg', upsert: true);
      await storage.uploadBinary('$uid/cni_recto.jpg', _recto!,
          fileOptions: opts);
      await storage.uploadBinary('$uid/cni_verso.jpg', _verso!,
          fileOptions: opts);
      await Supabase.instance.client
          .from('profiles')
          .update({'cni_status': 'pending'}).eq('id', uid);
      ref.invalidate(userProfileProvider);
      if (mounted) {
        Navigator.pop(context);
        _toast(context, 'CNI envoyée. Vérification en cours.');
      }
    } catch (e) {
      debugPrint('CNI upload error: $e');
      if (mounted) {
        setState(() => _error =
            'Envoi impossible. Vérifiez votre connexion et réessayez.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _slot(String label, Uint8List? bytes, bool recto) {
    return Expanded(
      child: GestureDetector(
        onTap: _busy ? null : () => _pick(recto),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: bytes != null ? AppColors.primary : AppColors.border),
          ),
          child: bytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.memory(bytes,
                      fit: BoxFit.cover, width: double.infinity),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined,
                        color: AppColors.primary),
                    const SizedBox(height: 6),
                    Text(label,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        )),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Vérifier ma CNI',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 6),
          const Text(
            'Envoyez des photos nettes du recto et du verso. '
            'Elles sont stockées de façon privée et ne sont vues que par '
            'l\'équipe de vérification.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _slot('Recto', _recto, true),
              const SizedBox(width: 12),
              _slot('Verso', _verso, false),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.error,
                )),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Envoyer pour vérification',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      )),
            ),
          ),
        ],
      ),
    );
  }
}
