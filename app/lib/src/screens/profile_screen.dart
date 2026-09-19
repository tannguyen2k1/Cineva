import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_network_image.dart';
import '../widgets/cineva_toast.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  bool _loading = false;
  bool _avatarLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) {
      context.go('/login');
      return;
    }
    _usernameCtrl.text = auth.user?.username ?? '';
    _fullNameCtrl.text = auth.user?.fullName ?? '';
    _emailCtrl.text = auth.user?.email ?? '';
    try {
      await auth.refreshUser();
      if (!mounted) return;
      _usernameCtrl.text = auth.user?.username ?? '';
      _fullNameCtrl.text = auth.user?.fullName ?? '';
      _emailCtrl.text = auth.user?.email ?? '';
      setState(() {});
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'channel-error'
          ? 'Cần dừng app và chạy lại (full restart) để đổi ảnh'
          : (e.message ?? e.code);
      showCinevaToast(context, msg, error: true);
      return;
    } catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.toString(), error: true);
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _avatarLoading = true);
    try {
      final avatar = await context.read<ApiClient>().uploadAvatar(
            file.path,
            filename: file.name,
          );
      if (!mounted) return;
      context.read<AuthState>().patchUser(avatar: avatar);
      showCinevaToast(context, 'Đã cập nhật ảnh đại diện');
    } on ApiException catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _avatarLoading = false);
    }
  }

  Future<void> _save() async {
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    if (password.isNotEmpty && password.length < 6) {
      showCinevaToast(context, 'Mật khẩu tối thiểu 6 ký tự', error: true);
      return;
    }
    if (password != confirm) {
      showCinevaToast(context, 'Mật khẩu xác nhận không khớp', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final data = await context.read<ApiClient>().updateProfile(
            fullName: _fullNameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: password.isEmpty ? null : password,
          );
      if (!mounted) return;
      context.read<AuthState>().patchUser(
            fullName: data['fullName']?.toString() ?? _fullNameCtrl.text.trim(),
            email: data['email']?.toString() ?? _emailCtrl.text.trim(),
            avatar: data['avatar']?.toString(),
          );
      _passwordCtrl.clear();
      _confirmCtrl.clear();
      showCinevaToast(context, 'Đã lưu hồ sơ');
      setState(() {});
    } on ApiException catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      showCinevaToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final name = user?.fullName?.isNotEmpty == true
        ? user!.fullName!
        : user?.username ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: CinevaColors.bg,
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _avatarLoading ? null : _pickAvatar,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CinevaColors.accent.withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _avatarLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : user?.avatar != null &&
                                    user!.avatar!.trim().isNotEmpty
                                ? CinevaNetworkImage(
                                    url: user.avatar,
                                    fit: BoxFit.cover,
                                  )
                                : ColoredBox(
                                    color: CinevaColors.accent
                                        .withValues(alpha: 0.2),
                                    child: Center(
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: CinevaColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CinevaColors.bg,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: CinevaColors.onAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user?.username ?? ''}',
                  style: const TextStyle(
                    color: CinevaColors.muted,
                    fontSize: 14,
                  ),
                ),
                if (user?.email != null && user!.email!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.email!,
                    style: const TextStyle(
                      color: CinevaColors.mutedSoft,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Thông tin cá nhân',
            subtitle: 'Cập nhật tên và email của bạn.',
            children: [
              TextField(
                readOnly: true,
                enabled: false,
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập',
                  helperText: 'Không thể đổi username',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fullNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  hintText: 'Nguyễn Văn A',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'ban@email.com',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Đổi mật khẩu',
            subtitle: 'Để trống nếu không muốn thay đổi.',
            children: [
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: CinevaColors.muted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
