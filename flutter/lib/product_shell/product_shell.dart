import 'package:flutter/material.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/foundation/foundation.dart';
import 'package:flutter_hbb/mobile/pages/home_page.dart';

import '../common.dart';

/// Product-facing shell for Ultimate Remote.
///
/// This layer is intentionally UI-only. Existing RustDesk remote-control
/// surfaces remain available through the native workspace entry point, while
/// enterprise services are represented by empty or placeholder states until
/// their contracts are implemented in a later phase.
class ProductShellPage extends StatefulWidget {
  const ProductShellPage({super.key});

  @override
  State<ProductShellPage> createState() => _ProductShellPageState();
}

enum _ShellSection {
  home,
  devices,
  sessions,
  connections,
  settings,
  profile,
  support,
  administration,
}

class _ShellDestination {
  const _ShellDestination({
    required this.section,
    required this.icon,
    required this.selectedIcon,
    required this.english,
    required this.arabic,
  });

  final _ShellSection section;
  final IconData icon;
  final IconData selectedIcon;
  final String english;
  final String arabic;
}

class _ProductShellPageState extends State<ProductShellPage> {
  _ShellSection _section = _ShellSection.home;
  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.system;

  static const List<_ShellDestination> _destinations = <_ShellDestination>[
    _ShellDestination(
      section: _ShellSection.home,
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
      english: 'Overview',
      arabic: 'نظرة عامة',
    ),
    _ShellDestination(
      section: _ShellSection.devices,
      icon: Icons.devices_other_outlined,
      selectedIcon: Icons.devices_other,
      english: 'Devices',
      arabic: 'الأجهزة',
    ),
    _ShellDestination(
      section: _ShellSection.sessions,
      icon: Icons.swap_horiz_outlined,
      selectedIcon: Icons.swap_horiz,
      english: 'Sessions',
      arabic: 'الجلسات',
    ),
    _ShellDestination(
      section: _ShellSection.connections,
      icon: Icons.link_outlined,
      selectedIcon: Icons.link,
      english: 'Connections',
      arabic: 'الاتصالات',
    ),
    _ShellDestination(
      section: _ShellSection.settings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      english: 'Settings',
      arabic: 'الإعدادات',
    ),
    _ShellDestination(
      section: _ShellSection.profile,
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle,
      english: 'Profile',
      arabic: 'الملف الشخصي',
    ),
    _ShellDestination(
      section: _ShellSection.support,
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent,
      english: 'Help & support',
      arabic: 'المساعدة والدعم',
    ),
    _ShellDestination(
      section: _ShellSection.administration,
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings,
      english: 'Role surfaces',
      arabic: 'واجهات الأدوار',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      locale: _locale,
      child: Builder(
        builder: (context) {
          final direction = _locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr;
          return Directionality(
            textDirection: direction,
            child: _buildResponsiveShell(context),
          );
        },
      ),
    );
  }

  Widget _buildResponsiveShell(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        final isRail = constraints.maxWidth < 1040;
        if (isCompact) {
          return Scaffold(
            backgroundColor: _colors(context).background,
            body: SafeArea(child: _buildMainContent(context)),
            bottomNavigationBar: _buildMobileNavigation(context),
          );
        }
        return Scaffold(
          backgroundColor: _colors(context).background,
          body: SafeArea(
            child: Row(
              children: <Widget>[
                _buildDesktopNavigation(context, isRail: isRail),
                Expanded(child: _buildMainContent(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopNavigation(BuildContext context, {required bool isRail}) {
    final colors = _colors(context);
    return Material(
      color: colors.surface,
      child: Container(
        width: isRail ? 86 : 248,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: colors.border),
          ),
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isRail
                    ? UltimateDesignTokens.spacingSm
                    : UltimateDesignTokens.spacingLg,
                vertical: UltimateDesignTokens.spacingXl,
              ),
              child: Semantics(
                header: true,
                label: ProductIdentity.productName,
                child: isRail
                    ? Icon(Icons.shield_outlined,
                        color: colors.brandTeal, size: 30)
                    : Row(
                        children: <Widget>[
                          Icon(Icons.shield_outlined,
                              color: colors.brandTeal, size: 30),
                          const SizedBox(width: UltimateDesignTokens.spacingSm),
                          Flexible(
                            child: Text(
                              ProductIdentity.productName,
                              style: UltimateDesignTokens.heading3.copyWith(
                                color: colors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isRail ? 8 : 12,
                  vertical: 4,
                ),
                children: _destinations
                    .map((destination) => _buildNavigationItem(
                          context,
                          destination,
                          compact: isRail,
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(UltimateDesignTokens.spacingLg),
              child: _buildEnvironmentBadge(context, compact: isRail),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context,
    _ShellDestination destination, {
    required bool compact,
  }) {
    final selected = _section == destination.section;
    final colors = _colors(context);
    final label = _label(context, destination.english, destination.arabic);
    final item = Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected ? colors.surfaceSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(UltimateDesignTokens.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(UltimateDesignTokens.radiusMd),
            onTap: () => setState(() => _section = destination.section),
            focusColor: colors.focus.withOpacity(.16),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: 11,
              ),
              child: compact
                  ? Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      color: selected ? colors.brandTeal : colors.textSecondary,
                    )
                  : Row(
                      children: <Widget>[
                        Icon(
                          selected
                              ? destination.selectedIcon
                              : destination.icon,
                          color: selected
                              ? colors.brandTeal
                              : colors.textSecondary,
                        ),
                        const SizedBox(width: UltimateDesignTokens.spacingMd),
                        Expanded(
                          child: Text(
                            label,
                            style: UltimateDesignTokens.body.copyWith(
                              color: selected
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
    return compact ? Tooltip(message: label, child: item) : item;
  }

  Widget _buildMobileNavigation(BuildContext context) {
    final colors = _colors(context);
    const mobileSections = <_ShellSection>[
      _ShellSection.home,
      _ShellSection.devices,
      _ShellSection.sessions,
      _ShellSection.settings,
    ];
    final items = mobileSections
        .map((section) =>
            _destinations.firstWhere((item) => item.section == section))
        .toList();
    final selectedIndex = items.indexWhere((item) => item.section == _section);
    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _section = items[index].section);
      },
      backgroundColor: colors.surface,
      indicatorColor: colors.surfaceSubtle,
      destinations: items
          .map(
            (item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: _label(context, item.english, item.arabic),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildTopBar(context),
        Expanded(
          child: AnimatedSwitcher(
            duration: UltimateDesignTokens.motionStandard,
            child: KeyedSubtree(
              key: ValueKey<_ShellSection>(_section),
              child: _buildSection(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final colors = _colors(context);
    final title = _destinations
        .firstWhere((destination) => destination.section == _section)
        .english;
    final localizedTitle = _label(
      context,
      title,
      _destinations
          .firstWhere((destination) => destination.section == _section)
          .arabic,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(
        UltimateDesignTokens.spacingXl,
        UltimateDesignTokens.spacingLg,
        UltimateDesignTokens.spacingXl,
        UltimateDesignTokens.spacingMd,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  localizedTitle,
                  style: UltimateDesignTokens.heading2.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: UltimateDesignTokens.spacingXs),
                Text(
                  _label(context, 'Ultimate Remote workspace',
                      'مساحة عمل Ultimate Remote'),
                  style: UltimateDesignTokens.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _buildEnvironmentBadge(context),
          const SizedBox(width: UltimateDesignTokens.spacingMd),
          Tooltip(
            message: _label(context, 'Profile', 'الملف الشخصي'),
            child: IconButton(
              onPressed: () => setState(() => _section = _ShellSection.profile),
              tooltip: _label(context, 'Profile', 'الملف الشخصي'),
              icon: Icon(Icons.account_circle_outlined,
                  color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context) {
    switch (_section) {
      case _ShellSection.home:
        return _buildOverview(context);
      case _ShellSection.devices:
        return _buildDevices(context);
      case _ShellSection.sessions:
        return _buildSessions(context);
      case _ShellSection.connections:
        return _buildConnections(context);
      case _ShellSection.settings:
        return _buildSettings(context);
      case _ShellSection.profile:
        return _buildLogin(context);
      case _ShellSection.support:
        return _buildSupport(context);
      case _ShellSection.administration:
        return _buildRoleSurfaces(context);
    }
  }

  Widget _buildOverview(BuildContext context) {
    return _scrollableBody(
      context,
      children: <Widget>[
        _buildIntro(context),
        Wrap(
          spacing: UltimateDesignTokens.spacingLg,
          runSpacing: UltimateDesignTokens.spacingLg,
          children: <Widget>[
            _buildOverviewCard(
              context,
              icon: Icons.devices_other_outlined,
              title: _label(context, 'Managed devices', 'الأجهزة المُدارة'),
              body: _label(context, 'No managed devices yet.',
                  'لا توجد أجهزة مُدارة بعد.'),
              action:
                  _label(context, 'Open device workspace', 'فتح مساحة الأجهزة'),
              onPressed: () => setState(() => _section = _ShellSection.devices),
            ),
            _buildOverviewCard(
              context,
              icon: Icons.swap_horiz_outlined,
              title: _label(context, 'Active sessions', 'الجلسات النشطة'),
              body:
                  _label(context, 'No active sessions.', 'لا توجد جلسات نشطة.'),
              action: _label(context, 'View sessions', 'عرض الجلسات'),
              onPressed: () =>
                  setState(() => _section = _ShellSection.sessions),
            ),
            _buildOverviewCard(
              context,
              icon: Icons.link_outlined,
              title: _label(context, 'Quick connection', 'اتصال سريع'),
              body: _label(
                  context,
                  'Open the existing remote workspace to connect using the RustDesk engine.',
                  'افتح مساحة التحكم عن بُعد الحالية للاتصال باستخدام محرك RustDesk.'),
              action: _label(
                  context, 'Open remote workspace', 'فتح مساحة التحكم عن بُعد'),
              onPressed: _openExistingWorkspace,
            ),
          ],
        ),
        const SizedBox(height: UltimateDesignTokens.spacing2xl),
        _buildSectionHeading(
          context,
          _label(context, 'Designed for clear, consistent work',
              'مصممة لعمل واضح ومتسق'),
          _label(
              context,
              'The product shell is ready for future device, session, and organization services without inventing production data.',
              'غلاف المنتج جاهز مستقبلًا لخدمات الأجهزة والجلسات والمؤسسات دون اختلاق بيانات إنتاجية.'),
        ),
        const SizedBox(height: UltimateDesignTokens.spacingLg),
        Wrap(
          spacing: UltimateDesignTokens.spacingMd,
          runSpacing: UltimateDesignTokens.spacingMd,
          children: <Widget>[
            _buildPill(
                context,
                Icons.shield_outlined,
                _label(context, 'RustDesk engine preserved',
                    'محرك RustDesk محفوظ')),
            _buildPill(context, Icons.translate,
                _label(context, 'Arabic / English', 'العربية / English')),
            _buildPill(context, Icons.devices,
                _label(context, 'Responsive shell', 'غلاف متجاوب')),
          ],
        ),
      ],
    );
  }

  Widget _buildIntro(BuildContext context) {
    final colors = _colors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(UltimateDesignTokens.spacingXl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[colors.brandNavy, colors.brandTeal],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(UltimateDesignTokens.radiusLg),
      ),
      child: Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _label(context, 'Welcome to Ultimate Remote',
                  'مرحبًا بك في Ultimate Remote'),
              style: UltimateDesignTokens.display
                  .copyWith(color: colors.textInverse),
            ),
            const SizedBox(height: UltimateDesignTokens.spacingSm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(
                _label(
                    context,
                    'A focused workspace for remote support and device operations.',
                    'مساحة عمل مركزة للدعم عن بُعد وعمليات الأجهزة.'),
                style: UltimateDesignTokens.bodyLarge.copyWith(
                  color: colors.textInverse.withOpacity(.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevices(BuildContext context) {
    return _scrollableBody(
      context,
      children: <Widget>[
        _buildSectionHeading(
          context,
          _label(context, 'Devices', 'الأجهزة'),
          _label(
              context,
              'Managed device inventory will appear here when a service is connected.',
              'ستظهر قائمة الأجهزة المُدارة هنا عند ربط الخدمة.'),
        ),
        const SizedBox(height: UltimateDesignTokens.spacingXl),
        _buildEmptyState(
          context,
          icon: Icons.devices_other_outlined,
          title: _label(context, 'No managed devices', 'لا توجد أجهزة مُدارة'),
          message: _label(
              context,
              'There are no device records to display yet. Use the existing remote workspace for direct RustDesk connections.',
              'لا توجد سجلات أجهزة لعرضها بعد. استخدم مساحة التحكم الحالية للاتصالات المباشرة عبر RustDesk.'),
          actionLabel: _label(
              context, 'Open remote workspace', 'فتح مساحة التحكم عن بُعد'),
          onAction: _openExistingWorkspace,
        ),
        const SizedBox(height: UltimateDesignTokens.spacingLg),
        _buildSurface(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildSectionHeading(
                context,
                _label(context, 'Device status states', 'حالات الجهاز'),
                _label(
                    context,
                    'Status indicators are ready for future device data.',
                    'مؤشرات الحالة جاهزة لبيانات الأجهزة المستقبلية.'),
              ),
              const SizedBox(height: UltimateDesignTokens.spacingLg),
              Wrap(
                spacing: UltimateDesignTokens.spacingLg,
                runSpacing: UltimateDesignTokens.spacingMd,
                children: <Widget>[
                  _buildStatusIndicator(
                      context,
                      _label(context, 'Online', 'متصل'),
                      _colors(context).success),
                  _buildStatusIndicator(
                      context,
                      _label(context, 'Offline', 'غير متصل'),
                      _colors(context).textSecondary),
                  _buildStatusIndicator(
                      context,
                      _label(context, 'Connecting', 'جارٍ الاتصال'),
                      _colors(context).info),
                  _buildStatusIndicator(
                      context,
                      _label(context, 'Connected', 'متصل بالجلسة'),
                      _colors(context).brandTeal),
                  _buildStatusIndicator(
                      context,
                      _label(context, 'Busy', 'مشغول'),
                      _colors(context).warning),
                  _buildStatusIndicator(
                      context,
                      _label(context, 'Unknown', 'غير معروف'),
                      _colors(context).error),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessions(BuildContext context) {
    return _scrollableBody(
      context,
      children: <Widget>[
        _buildSectionHeading(
          context,
          _label(context, 'Sessions', 'الجلسات'),
          _label(
              context,
              'Session history and live status are reserved for the session service contract.',
              'سجل الجلسات والحالة المباشرة محفوظان لعقد خدمة الجلسات.'),
        ),
        const SizedBox(height: UltimateDesignTokens.spacingXl),
        _buildEmptyState(
          context,
          icon: Icons.swap_horiz_outlined,
          title: _label(context, 'No sessions', 'لا توجد جلسات'),
          message: _label(
              context,
              'No session records are available in this UI shell.',
              'لا تتوفر سجلات جلسات في غلاف الواجهة هذا.'),
          actionLabel: _label(context, 'Start from remote workspace',
              'البدء من مساحة التحكم عن بُعد'),
          onAction: _openExistingWorkspace,
        ),
        const SizedBox(height: UltimateDesignTokens.spacingLg),
        _buildSessionShellPreview(context),
      ],
    );
  }

  Widget _buildSessionShellPreview(BuildContext context) {
    final colors = _colors(context);
    return _buildSurface(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.desktop_windows_outlined, color: colors.brandTeal),
              const SizedBox(width: UltimateDesignTokens.spacingSm),
              Expanded(
                child: Text(
                  _label(
                      context, 'Remote session shell', 'غلاف الجلسة عن بُعد'),
                  style: UltimateDesignTokens.heading3
                      .copyWith(color: colors.textPrimary),
                ),
              ),
              _buildStatusIndicator(
                  context,
                  _label(context, 'Disconnected', 'غير متصل'),
                  colors.textSecondary),
            ],
          ),
          const SizedBox(height: UltimateDesignTokens.spacingLg),
          Wrap(
            spacing: UltimateDesignTokens.spacingXl,
            runSpacing: UltimateDesignTokens.spacingMd,
            children: <Widget>[
              _buildInfoRow(
                  context,
                  _label(context, 'Remote device', 'الجهاز البعيد'),
                  _label(context, 'Not selected', 'لم يتم الاختيار')),
              _buildInfoRow(
                  context, _label(context, 'Duration', 'المدة'), '--:--'),
              _buildInfoRow(context, _label(context, 'Quality', 'الجودة'),
                  _label(context, 'Not available', 'غير متاحة')),
            ],
          ),
          const SizedBox(height: UltimateDesignTokens.spacingLg),
          Wrap(
            spacing: UltimateDesignTokens.spacingSm,
            runSpacing: UltimateDesignTokens.spacingSm,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.fullscreen),
                label: Text(_label(context, 'Fullscreen', 'ملء الشاشة')),
              ),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.input),
                label: Text(_label(context, 'Input controls', 'عناصر التحكم')),
              ),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.folder_outlined),
                label: Text(_label(context, 'File transfer', 'نقل الملفات')),
              ),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.close),
                label: Text(_label(context, 'Disconnect', 'قطع الاتصال')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnections(BuildContext context) {
    final colors = _colors(context);
    return _scrollableBody(
      context,
      children: <Widget>[
        _buildSectionHeading(
          context,
          _label(context, 'Connections', 'الاتصالات'),
          _label(
              context,
              'Connection actions remain in the existing RustDesk workspace until product services are connected.',
              'تبقى إجراءات الاتصال في مساحة RustDesk الحالية إلى حين ربط خدمات المنتج.'),
        ),
        const SizedBox(height: UltimateDesignTokens.spacingXl),
        _buildSurface(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _label(context, 'Connect to a device', 'الاتصال بجهاز'),
                style: UltimateDesignTokens.heading3
                    .copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: UltimateDesignTokens.spacingSm),
              Text(
                _label(
                    context,
                    'The product shell does not perform networking. It hands off to the existing remote workspace.',
                    'غلاف المنتج لا ينفذ الشبكات؛ بل ينقلك إلى مساحة التحكم الحالية.'),
                style: UltimateDesignTokens.body
                    .copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: UltimateDesignTokens.spacingLg),
              TextField(
                decoration: InputDecoration(
                  labelText: _label(context, 'Remote ID (visual placeholder)',
                      'معرّف الجهاز (عنصر واجهة)'),
                  hintText: _label(
                      context,
                      'Enter a device ID in the remote workspace',
                      'أدخل معرّف الجهاز في مساحة التحكم عن بُعد'),
                  prefixIcon: const Icon(Icons.tag),
                ),
                readOnly: true,
                enableInteractiveSelection: false,
              ),
              const SizedBox(height: UltimateDesignTokens.spacingLg),
              _primaryButton(
                context,
                label: _label(context, 'Open remote workspace',
                    'فتح مساحة التحكم عن بُعد'),
                icon: Icons.open_in_new,
                onPressed: _openExistingWorkspace,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogin(BuildContext context) {
    final colors = _colors(context);
    return _scrollableBody(
      context,
      children: <Widget>[
        _buildSectionHeading(
          context,
          _label(context, 'Account', 'الحساب'),
          _label(
              context,
              'A future account service can connect to this UI without changing the shell.',
              'يمكن لخدمة الحساب المستقبلية الاتصال بهذه الواجهة دون تغيير الغلاف.'),
        ),
        const SizedBox(height: UltimateDesignTokens.spacingXl),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _buildSurface(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.lock_outline, color: colors.brandTeal),
                    const SizedBox(width: UltimateDesignTokens.spacingSm),
                    Text(
                      _label(context, 'Sign in', 'تسجيل الدخول'),
                      style: UltimateDesignTokens.heading3
                          .copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: UltimateDesignTokens.spacingLg),
                TextField(
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const <String>[AutofillHints.username],
                  decoration: InputDecoration(
                    labelText: _label(context, 'Email or username',
                        'البريد الإلكتروني أو اسم المستخدم'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: UltimateDesignTokens.spacingMd),
                TextField(
                  obscureText: true,
                  autofillHints: const <String>[AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: _label(context, 'Password', 'كلمة المرور'),
                    prefixIcon: const Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: UltimateDesignTokens.spacingLg),
                SizedBox(
                  width: double.infinity,
                  child: _primaryButton(
                    context,
                    label: _label(context, 'Continue (service not connected)',
                        'متابعة (الخدمة غير متصلة)'),
                    icon: Icons.arrow_forward,
                    onPressed: null,
                  ),
                ),
                const SizedBox(height: UltimateDesignTokens.spacingMd),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(_label(context, 'SSO / OIDC (future)',
                        'SSO / OIDC (مستقبلًا)')),
                  ),
                ),
                const SizedBox(height: UltimateDesignTokens.spacingSm),
                Text(
                  _label(
                      context,
                      'MFA and authentication backend are intentionally not implemented in this phase.',
                      'لم يتم تنفيذ MFA أو backend للمصادقة عمدًا في هذه المرحلة.'),
                  style: UltimateDesignTokens.caption
                      .copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettings(BuildContext context) {
    final colors = _colors(context);
    return _scrollableBody(
      context,
      children: <Widget>[
        _buildSectionHeading(
          context,
          _label(context, 'Settings', 'الإعدادات'),
          _label(
              context,
              'Appearance and language controls for the product shell.',
              'إعدادات المظهر واللغة لغلاف المنتج.'),
        ),
        const SizedBox(height: UltimateDesignTokens.spacingXl),
        _buildSurface(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_label(context, 'Appearance', 'المظهر'),
                  style: UltimateDesignTokens.heading3
                      .copyWith(color: colors.textPrimary)),
              const SizedBox(height: UltimateDesignTokens.spacingMd),
              DropdownButtonFormField<ThemeMode>(
                value: _themeMode,
                decoration: InputDecoration(
                  labelText: _label(context, 'Theme mode', 'وضع المظهر'),
                  prefixIcon: const Icon(Icons.brightness_6_outlined),
                ),
                items: <DropdownMenuItem<ThemeMode>>[
                  DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text(_label(context, 'System', 'النظام'))),
                  DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text(_label(context, 'Light', 'فاتح'))),
                  DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text(_label(context, 'Dark', 'داكن'))),
                ],
                onChanged: (mode) {
                  if (mode == null) return;
                  setState(() => _themeMode = mode);
                  MyTheme.changeDarkMode(mode);
                },
              ),
              const SizedBox(height: UltimateDesignTokens.spacingLg),
              DropdownButtonFormField<Locale>(
                value: _locale,
                decoration: InputDecoration(
                  labelText: _label(context, 'Language', 'اللغة'),
                  prefixIcon: const Icon(Icons.translate),
                ),
                items: const <DropdownMenuItem<Locale>>[
                  DropdownMenuItem(value: Locale('en'), child: Text('English')),
                  DropdownMenuItem(value: Locale('ar'), child: Text('العربية')),
                ],
                onChanged: (locale) {
                  if (locale == null) return;
                  setState(() => _locale = locale);
                },
              ),
              const SizedBox(height: UltimateDesignTokens.spacingLg),
              Text(
                  _label(context, 'Future product settings',
                      'إعدادات المنتج المستقبلية'),
                  style: UltimateDesignTokens.heading3
                      .copyWith(color: colors.textPrimary)),
              const SizedBox(height: UltimateDesignTokens.spacingSm),
              _buildSettingsPlaceholder(context, Icons.tune,
                  _label(context, 'Connection preferences', 'تفضيلات الاتصال')),
              _buildSettingsPlaceholder(context, Icons.security,
                  _label(context, 'Security policy', 'سياسة الأمان')),
              _buildSettingsPlaceholder(context, Icons.notifications_none,
                  _label(context, 'Notifications', 'الإشعارات')),
            ],
          ),
        ),
        const SizedBox(height: UltimateDesignTokens.spacingXl),
        _buildAbout(context),
      ],
    );
  }

  Widget _buildSettingsPlaceholder(
      BuildContext context, IconData icon, String label) {
    final colors = _colors(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.textSecondary),
      title: Text(label, style: TextStyle(color: colors.textPrimary)),
      subtitle: Text(
          _label(context, 'Placeholder — no backend behavior',
              'عنصر نائب — بلا سلوك backend'),
          style: TextStyle(color: colors.textSecondary)),
      trailing: const Icon(Icons.chevron_right),
      enabled: false,
    );
  }

  Widget _buildAbout(BuildContext context) {
    final colors = _colors(context);
    return _buildSurface(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_label(context, 'About', 'حول التطبيق'),
              style: UltimateDesignTokens.heading3
                  .copyWith(color: colors.textPrimary)),
          const SizedBox(height: UltimateDesignTokens.spacingMd),
          _buildInfoRow(context, _label(context, 'Product', 'المنتج'),
              ProductIdentity.productName),
          _buildInfoRow(
              context, _label(context, 'Version', 'الإصدار'), '1.4.9+67'),
          _buildInfoRow(context, _label(context, 'Build', 'البناء'),
              _label(context, 'Local debug shell', 'غلاف تطوير محلي')),
          const SizedBox(height: UltimateDesignTokens.spacingMd),
          Text(
            ProductIdentity.attributionNotice,
            style:
                UltimateDesignTokens.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: UltimateDesignTokens.spacingSm),
          Text(
            _label(
                context,
                'Required licensing and third-party notices remain part of the product distribution.',
                'تبقى إشعارات التراخيص والجهات الخارجية المطلوبة جزءًا من توزيع المنتج.'),
            style: UltimateDesignTokens.caption
                .copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSupport(BuildContext context) {
    return _scrollableBody(
      context,
      children: <Widget>[
        _buildSectionHeading(
          context,
          _label(context, 'Help & support', 'المساعدة والدعم'),
          _label(
              context,
              'Support workflows will be connected to a future service contract.',
              'ستُربط مسارات الدعم بعقد خدمة مستقبلي.'),
        ),
        const SizedBox(height: UltimateDesignTokens.spacingXl),
        _buildEmptyState(
          context,
          icon: Icons.support_agent_outlined,
          title:
              _label(context, 'Support surface placeholder', 'عنصر نائب للدعم'),
          message: _label(context, 'No support queue or ticket data is loaded.',
              'لم يتم تحميل بيانات طابور الدعم أو التذاكر.'),
          actionLabel: _label(
              context, 'Open remote workspace', 'فتح مساحة التحكم عن بُعد'),
          onAction: _openExistingWorkspace,
        ),
      ],
    );
  }

  Widget _buildRoleSurfaces(BuildContext context) {
    return _scrollableBody(
      context,
      children: <Widget>[
        _buildSectionHeading(
          context,
          _label(context, 'Role surfaces', 'واجهات الأدوار'),
          _label(
              context,
              'Navigation separation only. No authorization or RBAC is implemented here.',
              'فصل للواجهات فقط. لم يتم تنفيذ authorization أو RBAC هنا.'),
        ),
        const SizedBox(height: UltimateDesignTokens.spacingXl),
        Wrap(
          spacing: UltimateDesignTokens.spacingLg,
          runSpacing: UltimateDesignTokens.spacingLg,
          children: <Widget>[
            _buildRoleCard(
                context,
                Icons.person_outline,
                _label(context, 'End user', 'المستخدم النهائي'),
                _label(context, 'My devices, connections, sessions, settings',
                    'أجهزتي، اتصالاتي، جلساتي، إعداداتي')),
            _buildRoleCard(
                context,
                Icons.engineering_outlined,
                _label(context, 'Technician', 'الفني'),
                _label(context, 'Devices, remote sessions, session history',
                    'الأجهزة، الجلسات عن بُعد، سجل الجلسات')),
            _buildRoleCard(
                context,
                Icons.groups_outlined,
                _label(context, 'Organization admin', 'مسؤول المؤسسة'),
                _label(context, 'Organization, users, teams, policies, audit',
                    'المؤسسة، المستخدمون، الفرق، السياسات، التدقيق')),
            _buildRoleCard(
                context,
                Icons.admin_panel_settings_outlined,
                _label(context, 'Super admin', 'المسؤول الأعلى'),
                _label(context, 'Organizations, global devices, system health',
                    'المؤسسات، الأجهزة العامة، صحة النظام')),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleCard(
      BuildContext context, IconData icon, String title, String body) {
    final colors = _colors(context);
    return SizedBox(
      width: 300,
      child: _buildSurface(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colors.brandTeal, size: 28),
            const SizedBox(height: UltimateDesignTokens.spacingMd),
            Text(title,
                style: UltimateDesignTokens.heading3
                    .copyWith(color: colors.textPrimary)),
            const SizedBox(height: UltimateDesignTokens.spacingSm),
            Text(body,
                style: UltimateDesignTokens.body
                    .copyWith(color: colors.textSecondary)),
            const SizedBox(height: UltimateDesignTokens.spacingMd),
            _buildStatusIndicator(
                context,
                _label(context, 'UI placeholder', 'عنصر واجهة نائب'),
                colors.info),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required String action,
    required VoidCallback onPressed,
  }) {
    final colors = _colors(context);
    return SizedBox(
      width: 310,
      child: _buildSurface(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colors.brandTeal, size: 28),
            const SizedBox(height: UltimateDesignTokens.spacingMd),
            Text(title,
                style: UltimateDesignTokens.heading3
                    .copyWith(color: colors.textPrimary)),
            const SizedBox(height: UltimateDesignTokens.spacingSm),
            Text(body,
                style: UltimateDesignTokens.body
                    .copyWith(color: colors.textSecondary)),
            const SizedBox(height: UltimateDesignTokens.spacingLg),
            TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final colors = _colors(context);
    return _buildSurface(
      context,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 56, color: colors.textSecondary),
              const SizedBox(height: UltimateDesignTokens.spacingLg),
              Text(title,
                  textAlign: TextAlign.center,
                  style: UltimateDesignTokens.heading2
                      .copyWith(color: colors.textPrimary)),
              const SizedBox(height: UltimateDesignTokens.spacingSm),
              Text(message,
                  textAlign: TextAlign.center,
                  style: UltimateDesignTokens.bodyLarge
                      .copyWith(color: colors.textSecondary)),
              const SizedBox(height: UltimateDesignTokens.spacingLg),
              _primaryButton(context,
                  label: actionLabel,
                  icon: Icons.open_in_new,
                  onPressed: onAction),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeading(
      BuildContext context, String title, String subtitle) {
    final colors = _colors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title,
            style: UltimateDesignTokens.heading1
                .copyWith(color: colors.textPrimary)),
        const SizedBox(height: UltimateDesignTokens.spacingSm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Text(subtitle,
              style: UltimateDesignTokens.bodyLarge
                  .copyWith(color: colors.textSecondary)),
        ),
      ],
    );
  }

  Widget _scrollableBody(BuildContext context,
      {required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(UltimateDesignTokens.spacingXl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurface(BuildContext context, {required Widget child}) {
    final colors = _colors(context);
    return Container(
      padding: const EdgeInsets.all(UltimateDesignTokens.spacingXl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(UltimateDesignTokens.radiusLg),
        border: Border.all(color: colors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.brandNavy.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _primaryButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _buildPill(BuildContext context, IconData icon, String label) {
    final colors = _colors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(UltimateDesignTokens.radiusPill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17, color: colors.brandTeal),
          const SizedBox(width: UltimateDesignTokens.spacingSm),
          Text(label, style: TextStyle(color: colors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildEnvironmentBadge(BuildContext context, {bool compact = false}) {
    final colors = _colors(context);
    final label = _label(context, 'Development', 'تطوير');
    return Tooltip(
      message: _label(context, 'Environment placeholder', 'عنصر نائب للبيئة'),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(UltimateDesignTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.info,
                shape: BoxShape.circle,
              ),
            ),
            if (!compact) ...<Widget>[
              const SizedBox(width: UltimateDesignTokens.spacingSm),
              Text(label, style: TextStyle(color: colors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final colors = _colors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: UltimateDesignTokens.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: colors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: colors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(
      BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: UltimateDesignTokens.spacingSm),
        Text(label, style: TextStyle(color: _colors(context).textSecondary)),
      ],
    );
  }

  UltimateThemeExtension _colors(BuildContext context) {
    return Theme.of(context).extension<UltimateThemeExtension>() ??
        UltimateThemeExtension.light;
  }

  String _label(BuildContext context, String english, String arabic) {
    return Localizations.localeOf(context).languageCode == 'ar'
        ? arabic
        : english;
  }

  void _openExistingWorkspace() {
    final target = isDesktop ? const DesktopTabPage() : HomePage();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => target),
    );
  }
}
