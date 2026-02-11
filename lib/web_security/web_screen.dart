import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../channel/platform_channel.dart';
import '../style/theme.dart';
import '../style/icons.dart';
import '../strings.dart';
import '../security_status_helper.dart';
import 'bottomsheet/manage_app_bottomsheet.dart';
import 'bottomsheet/manage_dns_bottomsheet.dart';
import '../style/ui/custom_dialog.dart';
import '../style/ui/feature_note_dialog.dart';

enum _VpnState { notConnected, preparing, connected }

class WebSecurityScreen extends StatefulWidget {
  const WebSecurityScreen({super.key});

  @override
  State<WebSecurityScreen> createState() => _WebSecurityScreenState();
}

class _WebSecurityScreenState extends State<WebSecurityScreen>
    with WidgetsBindingObserver {
  final TextEditingController _pkgController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();

  final String _prefsPkgsKey = 'web_vpn_blocked_packages';
  final String _prefsDomainsKey = 'web_vpn_dns_blocklist';
  final String _prefsDnsUniversalKey = 'web_vpn_dns_universal_enabled';

  List<String> _packages = <String>[];
  List<String> _domains = <String>[];
  bool _universalDnsEnabled = false; // default off to avoid on->off flicker
  bool _configLoaded = false; // gate UI until loaded
  bool _isOpeningAppsSheet = false; // prevent rapid re-entry

  // Live counters
  int _bytesIn = 0;
  int _bytesOut = 0;
  int _dnsQueries = 0;
  int _dnsBlocked = 0;
  Timer? _counterTimer;

  // Connection state
  _VpnState _vpnState = _VpnState.notConnected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefsAndSync();
    _startCounterPolling();
    _refreshVpnState();
    // Prime global security status with current VPN and flags
    _pushSecurityStatusFromWeb();
  }

  @override
  void dispose() {
    _pkgController.dispose();
    _domainController.dispose();
    _counterTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app returns to foreground, re-check VPN running state immediately
    if (state == AppLifecycleState.resumed) {
      _refreshVpnState();
    }
  }

  Future<void> _loadPrefsAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    final pkgs = prefs.getStringList(_prefsPkgsKey) ?? <String>[];
    final domains = prefs.getStringList(_prefsDomainsKey) ?? <String>[];
    // Fetch universal DNS state from native (authoritative), fallback to cached prefs
    bool universal = await PlatformChannel.vpnGetUniversalDnsEnabled();
    if (!universal && !(prefs.getBool(_prefsDnsUniversalKey) ?? true)) {
      universal = false;
    }
    setState(() {
      _packages = pkgs;
      _domains = domains;
      _universalDnsEnabled = universal;
      _configLoaded = true;
    });
    // Sync cached config to native on screen open
    if (pkgs.isNotEmpty) {
      await PlatformChannel.vpnSetBlockedPackages(pkgs);
    }
    if (domains.isNotEmpty) {
      await PlatformChannel.vpnSetDnsBlocklist(domains);
    }
    // Push toggle state as well
    await PlatformChannel.vpnSetUniversalDnsEnabled(_universalDnsEnabled);
  }

  Future<void> _savePackages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsPkgsKey, _packages);
  }

  Future<void> _saveDomains() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsDomainsKey, _domains);
  }

  Future<void> _setUniversalDns(bool enabled) async {
    setState(() => _universalDnsEnabled = enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsDnsUniversalKey, enabled);
    await PlatformChannel.vpnSetUniversalDnsEnabled(enabled);
    // Mutual exclusivity: if universal is enabled, clear per-app list so VPN captures all apps
    if (enabled) {
      setState(() => _packages = <String>[]);
      await _savePackages();
      await PlatformChannel.vpnSetBlockedPackages(const <String>[]);
    } else {
      // Guard: when switching to Per-App (disabling Universal), stop VPN so new rules apply on next start
      await _stopVpnIfConnected(WebStrings.vpnStoppingUniversalOff);
    }
  }

  Future<void> _stopVpnIfConnected([String? reason]) async {
    if (_vpnState == _VpnState.connected) {
      final ok = await PlatformChannel.vpnStop();
      if (!mounted) return;
      if (ok) {
        setState(() => _vpnState = _VpnState.notConnected);
        if (reason != null && reason.isNotEmpty) {
          // Simple bottom toast
          showAppToast(
            context,
            reason,
            duration: const Duration(milliseconds: 1500),
          );
        }
      }
    }
  }

  void _startCounterPolling() {
    // Poll every 1s; lightweight map fetch over MethodChannel
    _counterTimer?.cancel();
    _counterTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final data = await PlatformChannel.vpnGetCounters();
      if (!mounted) return;
      setState(() {
        _bytesIn = data['bytesIn'] ?? 0;
        _bytesOut = data['bytesOut'] ?? 0;
        _dnsQueries = data['dnsQueries'] ?? 0;
        _dnsBlocked = data['dnsBlocked'] ?? 0;
      });
      // Also keep connection state in sync with native unless we're in preparing state
      if (_vpnState != _VpnState.preparing) {
        final active = await PlatformChannel.vpnIsActive();
        if (!mounted) return;
        final desired = active ? _VpnState.connected : _VpnState.notConnected;
        if (desired != _vpnState) {
          setState(() => _vpnState = desired);
          // Push update when connection state flips
          _pushSecurityStatusFromWeb();
        }
      }
    });
  }

  Future<void> _pushSecurityStatusFromWeb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final smsEnabled = prefs.getBool('sms_scanning_enabled') ?? false;
      final webEnabled = await PlatformChannel.vpnIsActive();
      final deviceThreats = (await PlatformChannel.talsecGetThreats()).length;
      final hasMaliciousApps =
          (await PlatformChannel.talsecGetSuspiciousPackages()).isNotEmpty;
      SecurityStatusHelper.updateSecurityStatus(
        deviceThreats: deviceThreats,
        smsThreats: 0,
        webThreats: 0,
        hasMaliciousApps: hasMaliciousApps,
        smsEnabled: smsEnabled,
        webEnabled: webEnabled,
        deviceEnabled: true,
        deviceThreatDetails: const [],
      );
    } catch (_) {}
  }

  Future<void> _refreshVpnState() async {
    final active = await PlatformChannel.vpnIsActive();
    if (!mounted) return;
    if (_vpnState != _VpnState.preparing) {
      setState(
        () => _vpnState = active ? _VpnState.connected : _VpnState.notConnected,
      );
    }
    // Reflect any state change to Home/global
    _pushSecurityStatusFromWeb();
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = bytes.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[i]}';
  }

  bool _validPackage(String input) {
    // Basic heuristic: expect at least 2 dots (com.example.app)
    return RegExp(r'^[a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)+$').hasMatch(input);
  }

  bool _validDomain(String input) {
    // Simple domain validation (no scheme, no spaces)
    return RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(input);
  }

  void _showSnack(String msg) {
    showAppToast(context, msg);
  }

  Future<void> _onToggleVpn() async {
    if (_vpnState == _VpnState.connected) {
      final ok = await PlatformChannel.vpnStop();
      if (ok) {
        setState(() => _vpnState = _VpnState.notConnected);
        _showSnack(AppStrings.disabled);
        await _pushSecurityStatusFromWeb();
      }
      return;
    }
    // Not connected -> Preparing -> Start
    // Guard: If Universal DNS is OFF and there are no selected apps,
    // auto-enable Universal DNS so VPN provides protection.
    if (!_universalDnsEnabled && _packages.isEmpty) {
      await _setUniversalDns(true);
    }
    setState(() => _vpnState = _VpnState.preparing);
    final prepared = await PlatformChannel.vpnPrepare();
    if (!prepared) {
      setState(() => _vpnState = _VpnState.notConnected);
      _showSnack(WebStrings.vpnNotReady);
      return;
    }
    final started = await PlatformChannel.vpnStart();
    setState(
      () => _vpnState = started ? _VpnState.connected : _VpnState.notConnected,
    );
    _showSnack(started ? AppStrings.enabled : AppStrings.disabled);
    await _pushSecurityStatusFromWeb();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor =
        isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight;

    // Make navigation bar transparent; keep icons legible per theme.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: bgColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          WebStrings.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.learnMore,
            icon: const Icon(Icons.info_outline),
            onPressed: () => FeatureNoteDialog.show(context, FeatureType.web),
          ),
        ],
      ),
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Decide based on ACTUAL available height in this padded, safe area.
              // Any height below ~820 typically requires scrolling for this screen.
              final isSmall = constraints.maxHeight < 740;
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Card (live counters)
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.language,
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              WebStrings.webStats,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _statusCardContent(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Per-app blocking
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppIcons.getFeatureIcon(
                              AppIcons.blocklist,
                              context: context,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              WebStrings.blockingMethod,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Universal DNS filtering toggle moved under Per-App section
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor
                                  .withOpacity(0.13),
                              radius: 18,
                              child: Icon(
                                Icons.dns,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : AppTheme.primaryColor,
                                size: 22,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            title: Text(
                              WebStrings.universalDnsFiltering,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              WebStrings.enableUniversalDns,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            trailing:
                                _configLoaded
                                    ? Switch(
                                      value: _universalDnsEnabled,
                                      onChanged: (v) => _setUniversalDns(v),
                                    )
                                    : SizedBox(
                                      width: 44,
                                      height: 24,
                                      child: Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor
                                  .withOpacity(0.13),
                              radius: 18,
                              child: Icon(
                                Icons.manage_accounts,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : AppTheme.primaryColor,
                                size: 22,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            title: Text(
                              WebStrings.manageAppDnsFilters,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    _universalDnsEnabled
                                        ? Theme.of(context).disabledColor
                                        : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black),
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color:
                                  _universalDnsEnabled
                                      ? Theme.of(context).disabledColor
                                      : (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white70
                                          : Colors.black45),
                            ),
                            enabled: !_universalDnsEnabled,
                            onTap:
                                _universalDnsEnabled ? null : _openManageApps,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _universalDnsEnabled
                              ? WebStrings.disableUniversalDns
                              : (_packages.isEmpty
                                  ? WebStrings.noAppsDnsApplied
                                  : '${_packages.length} ${WebStrings.appsDnsAppliedSuffix}'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // DNS blocklist
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppIcons.getFeatureIcon(
                              AppIcons.whitelist,
                              context: context,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              WebStrings.dnsBlocklist,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor
                                  .withOpacity(0.13),
                              radius: 18,
                              child: Icon(
                                Icons.manage_search,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : AppTheme.primaryColor,
                                size: 22,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            title: Text(
                              WebStrings.manageBlockedDomains,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : Colors.black45,
                            ),
                            onTap: _openManageDomains,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _domains.isEmpty
                              ? WebStrings.noDomainsBlocked
                              : '${_domains.length} ${WebStrings.domainsBlockedSuffix}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              );
              // Always use a scroll view to avoid layout overflow. Disable
              // user scrolling on medium-large screens so UX remains static.
              final bottomInset = MediaQuery.of(context).padding.bottom;
              return SingleChildScrollView(
                physics:
                    isSmall
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottomInset + 8),
                child: content,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text('$label: ', style: Theme.of(context).textTheme.bodyMedium),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _statusCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connection status
        Row(
          children: [
            Icon(
              _vpnState == _VpnState.connected
                  ? AppIcons.shieldProtected
                  : AppIcons.threat,
              color:
                  _vpnState == _VpnState.connected
                      ? AppTheme.successGreen
                      : Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Text(
              _vpnState == _VpnState.preparing
                  ? WebStrings.preparing
                  : (_vpnState == _VpnState.connected
                      ? WebStrings.connected
                      : WebStrings.notConnected),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // VPN Toggle Card
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: CircleAvatar(
              backgroundColor: (_vpnState == _VpnState.connected
                      ? AppTheme.successGreen
                      : AppTheme.primaryColor)
                  .withOpacity(0.13),
              radius: 18,
              child: Icon(
                _vpnState == _VpnState.preparing
                    ? Icons.hourglass_top
                    : (_vpnState == _VpnState.connected
                        ? Icons.stop
                        : Icons.play_arrow),
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : (_vpnState == _VpnState.connected
                            ? AppTheme.successGreen
                            : AppTheme.primaryColor),
                size: 22,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            title: Text(
              _vpnState == _VpnState.preparing
                  ? WebStrings.preparing
                  : (_vpnState == _VpnState.connected
                      ? WebStrings.stopVpn
                      : WebStrings.startVpn),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black45,
            ),
            onTap: _vpnState == _VpnState.preparing ? null : _onToggleVpn,
          ),
        ),
        const SizedBox(height: 12),
        _statItem(WebStrings.bytesIn, _formatBytes(_bytesIn), Icons.south_west),
        const SizedBox(height: 8),
        _statItem(
          WebStrings.bytesOut,
          _formatBytes(_bytesOut),
          Icons.north_east,
        ),
        const Divider(height: 24),
        _statItem(WebStrings.dnsQueries, '$_dnsQueries', Icons.query_stats),
        const SizedBox(height: 8),
        _statItem(WebStrings.dnsBlocked, '$_dnsBlocked', Icons.gpp_bad),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _statusCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connection status + toggle
        Row(
          children: [
            Icon(
              _vpnState == _VpnState.connected
                  ? AppIcons.shieldProtected
                  : AppIcons.threat,
              color:
                  _vpnState == _VpnState.connected
                      ? AppTheme.successGreen
                      : Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _vpnState == _VpnState.preparing
                    ? WebStrings.preparing
                    : (_vpnState == _VpnState.connected
                        ? WebStrings.connected
                        : WebStrings.notConnected),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _vpnToggleButton(),
          ],
        ),
        const SizedBox(height: 12),
        _statItem(WebStrings.bytesIn, _formatBytes(_bytesIn), Icons.south_west),
        const SizedBox(height: 8),
        _statItem(
          WebStrings.bytesOut,
          _formatBytes(_bytesOut),
          Icons.north_east,
        ),
        const Divider(height: 24),
        _statItem(WebStrings.dnsQueries, '$_dnsQueries', Icons.query_stats),
        const SizedBox(height: 8),
        _statItem(WebStrings.dnsBlocked, '$_dnsBlocked', Icons.gpp_bad),
      ],
    );
  }

  Widget _vpnToggleButton() {
    final isPreparing = _vpnState == _VpnState.preparing;
    final isConnected = _vpnState == _VpnState.connected;
    final label =
        isPreparing
            ? WebStrings.preparing
            : (isConnected ? WebStrings.stopVpn : WebStrings.startVpn);
    final icon =
        isPreparing
            ? Icons.hourglass_top
            : (isConnected ? Icons.stop : Icons.play_arrow);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]!
                  : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isPreparing ? null : _onToggleVpn,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                isPreparing
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Icon(
                      icon,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppTheme.primaryColor,
                    ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Inline add UI removed in favor of bottom sheets

  // Chips view removed to reduce clutter

  Future<void> _openManageApps() async {
    if (_isOpeningAppsSheet) return;
    _isOpeningAppsSheet = true;
    final updated = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => ManageAppBottomSheet(
            initialItems: _packages,
            validator: _validPackage,
            onApply: (list) async {
              setState(() => _packages = List<String>.from(list));
              await _savePackages();
              // Guard: rules changed while VPN is running -> stop VPN to ensure new rules on next start
              await _stopVpnIfConnected(
                WebStrings.vpnStoppingAppFiltersChanged,
              );
              // Don't close the bottom sheet - let user continue managing apps
            },
          ),
    );
    _isOpeningAppsSheet = false;
    if (updated != null) {
      // optionally sync immediately
      await PlatformChannel.vpnSetBlockedPackages(updated);
    }
  }

  Future<void> _openManageDomains() async {
    final updated = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => ManageDnsBottomSheet(
            initialItems: _domains,
            validator: _validDomain,
            onApply: (list) async {
              setState(() => _domains = List<String>.from(list));
              await _saveDomains();
              // Guard: DNS blocklist changed while VPN is running -> stop VPN
              await _stopVpnIfConnected(
                WebStrings.vpnStoppingDnsBlocklistChanged,
              );
              // Don't close the bottom sheet - let user continue managing domains
            },
          ),
    );
    if (updated != null) {
      // optionally sync immediately
      await PlatformChannel.vpnSetDnsBlocklist(updated);
    }
  }

  // Removed Apply button widget
}
