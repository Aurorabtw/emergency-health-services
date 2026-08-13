import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../models/organization_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/app_animations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  OrganizationModel? _organization;
  String? _loadedUserId;
  String? _loadedOrganizationId;
  String? _organizationError;
  bool _organizationLoading = false;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _syncingControllers = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateDirtyState);
    _phoneController.addListener(_updateDirtyState);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().user;
    if (user == null) return;

    if (_loadedUserId != user.uid && !_isDirty) {
      _loadedUserId = user.uid;
      _setControllers(user);
    }
    if (_loadedOrganizationId != user.organizationId) {
      _loadedOrganizationId = user.organizationId;
      _loadOrganization(user.organizationId);
    }
  }

  void _setControllers(UserModel user) {
    _syncingControllers = true;
    _nameController.text = user.name ?? '';
    _phoneController.text = user.phone ?? '';
    _isDirty = false;
    _syncingControllers = false;
  }

  void _updateDirtyState() {
    if (_syncingControllers) return;
    final user = context.read<AuthProvider>().user;
    final dirty = user != null &&
        (_nameController.text.trim() != (user.name ?? '').trim() ||
            _phoneController.text.trim() != (user.phone ?? '').trim());
    if (dirty != _isDirty && mounted) setState(() => _isDirty = dirty);
  }

  Future<void> _loadOrganization(String? organizationId) async {
    if (organizationId == null) {
      setState(() {
        _organization = null;
        _organizationLoading = false;
        _organizationError = null;
      });
      return;
    }

    setState(() {
      _organization = null;
      _organizationLoading = true;
      _organizationError = null;
    });
    final organization = await context
        .read<OrganizationProvider>()
        .getOrganization(organizationId);
    if (!mounted || _loadedOrganizationId != organizationId) return;
    setState(() {
      _organization = organization;
      _organizationLoading = false;
      _organizationError = organization == null
          ? 'Your assigned organization could not be loaded.'
          : null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await context.read<AuthProvider>().updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isDirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal details updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update your profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_updateDirtyState);
    _phoneController.removeListener(_updateDirtyState);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(child: _IdentityHeader(user: user)),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final personal = FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: _PersonalDetailsCard(
                      formKey: _formKey,
                      nameController: _nameController,
                      phoneController: _phoneController,
                      isSaving: _isSaving,
                      isDirty: _isDirty,
                      onSave: _save,
                    ),
                  );
                  final access = FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: _AccessCard(
                      user: user,
                      organization: _organization,
                      organizationLoading: _organizationLoading,
                      organizationError: _organizationError,
                    ),
                  );
                  if (!wide) {
                    return Column(
                      children: [personal, const SizedBox(height: 20), access],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: personal),
                      const SizedBox(width: 20),
                      Expanded(flex: 5, child: access),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  final UserModel user;

  const _IdentityHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = user.name?.trim().isNotEmpty == true
        ? user.name!.trim()
        : 'Complete your profile';
    final initial = user.name?.trim().isNotEmpty == true
        ? user.name!.trim()[0].toUpperCase()
        : user.email.isNotEmpty
            ? user.email[0].toUpperCase()
            : '?';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.primary, AppTheme.secondary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadowHover,
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
            ),
            child: Text(
              initial,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeaderBadge(
                      icon: Icons.shield_outlined,
                      label: user.roleLabel,
                    ),
                    _HeaderBadge(
                      icon: user.hasUsableContactProfile
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      label: user.hasUsableContactProfile
                          ? 'Contact ready'
                          : 'Contact incomplete',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PersonalDetailsCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool isSaving;
  final bool isDirty;
  final VoidCallback onSave;

  const _PersonalDetailsCard({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.isSaving,
    required this.isDirty,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.badge_outlined,
                title: 'Personal details',
                description:
                    'Keep your own contact information current. It may be used for bookings and operational communication.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: Validators.validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+880 1XXXXXXXXX',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: Validators.validatePhone,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Email, role, and organization access are read-only.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isSaving || !isDirty ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? 'Saving...' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  final UserModel user;
  final OrganizationModel? organization;
  final bool organizationLoading;
  final String? organizationError;

  const _AccessCard({
    required this.user,
    required this.organization,
    required this.organizationLoading,
    required this.organizationError,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Account and access',
              description:
                  'Your role determines which platform tools and records you can use.',
            ),
            const SizedBox(height: 22),
            _InfoRow(
              icon: Icons.alternate_email,
              label: 'Account email',
              value: user.email,
            ),
            const Divider(height: 26),
            _InfoRow(
              icon: Icons.security_outlined,
              label: 'Access role',
              value: user.roleLabel,
            ),
            const SizedBox(height: 20),
            _ScopeNotice(user: user),
            if (user.isOrgAdmin) ...[
              const SizedBox(height: 24),
              Text(
                'Assigned organization',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              if (organizationLoading)
                const LinearProgressIndicator(minHeight: 3)
              else if (organizationError != null)
                _MessageBox(
                  icon: Icons.warning_amber_rounded,
                  message: organizationError!,
                  color: AppTheme.warning,
                )
              else if (organization != null)
                _OrganizationDetails(organization: organization!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScopeNotice extends StatelessWidget {
  final UserModel user;

  const _ScopeNotice({required this.user});

  @override
  Widget build(BuildContext context) {
    final (icon, message, color) = user.isSuperAdmin
        ? (
            Icons.public,
            'Platform-wide administration across all organizations and users.',
            AppTheme.primary,
          )
        : user.isHospitalAdmin
            ? (
                Icons.local_hospital_outlined,
                'Legacy combined access: hospital beds and diagnostic tests.',
                AppTheme.warning,
              )
            : user.isBedAdmin
                ? (
                    Icons.bed_outlined,
                    'Service access: hospital beds and bed booking requests.',
                    AppTheme.primary,
                  )
                : user.isTestAdmin
                    ? (
                        Icons.science_outlined,
                        'Service access: diagnostic tests, serials, and queues.',
                        AppTheme.secondary,
                      )
                    : user.isBloodBankAdmin
                        ? (
                            Icons.bloodtype_outlined,
                            'Service access: blood inventory and blood requests.',
                            AppTheme.danger,
                          )
                        : user.isAmbulanceAdmin
                            ? (
                                Icons.emergency_outlined,
                                'Service access: ambulance fleet and requests.',
                                AppTheme.warning,
                              )
                            : (
                                Icons.health_and_safety_outlined,
                                'Patient access for healthcare search, bookings, and serials.',
                                AppTheme.success,
                              );
    return _MessageBox(icon: icon, message: message, color: color);
  }
}

class _MessageBox extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _MessageBox({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationDetails extends StatelessWidget {
  final OrganizationModel organization;

  const _OrganizationDetails({required this.organization});

  String get _typeLabel => switch (organization.type) {
        'hospital' => 'Hospital',
        'blood_bank' => 'Blood Bank',
        'ambulance_operator' => 'Ambulance Operator',
        _ => 'Organization',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  organization.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (organization.verified
                          ? AppTheme.success
                          : AppTheme.warning)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  organization.verified ? 'Verified' : 'Pending',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: organization.verified
                            ? AppTheme.success
                            : AppTheme.warning,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_typeLabel, style: Theme.of(context).textTheme.bodySmall),
          if (organization.address.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _CompactDetail(
              icon: Icons.location_on_outlined,
              value: organization.address,
            ),
          ],
          if (organization.phone.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _CompactDetail(
              icon: Icons.phone_outlined,
              value: organization.phone,
            ),
          ],
          if (organization.email?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _CompactDetail(
              icon: Icons.mail_outline,
              value: organization.email!,
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Organization details are managed by a platform administrator.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CompactDetail extends StatelessWidget {
  final IconData icon;
  final String value;

  const _CompactDetail({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppTheme.textSecondary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}
