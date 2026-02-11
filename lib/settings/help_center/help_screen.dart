import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../style/theme.dart';
import '../../style/icons.dart';
import '../../strings.dart';
import 'help_articles.dart';

class HelpScreen extends StatefulWidget {
  final String? openArticleId; // if provided, auto-open this article on load

  const HelpScreen({Key? key, this.openArticleId}) : super(key: key);

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

// Input decoration helper for the contact support form
InputDecoration _supportInputDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
  bool alignWithHint = false,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    labelText: label,
    alignLabelWithHint: alignWithHint,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: isDark ? Colors.grey[900] : Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

// Contact Support bottom sheet (Option 1: open email app with pre-filled content)
void _showContactSupportSheet(BuildContext context) {
  final emailCtrl = TextEditingController();
  final subjectCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor:
        Theme.of(context).brightness == Brightness.dark
            ? AppTheme.sheetBackgroundDark
            : AppTheme.sheetBackgroundLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final viewInsets = MediaQuery.of(ctx).viewInsets;
      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(AppIcons.support, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.helpContactSupport,
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.supportSubtitle,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email, size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            AppStrings.supportEmail,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: _supportInputDecoration(ctx,
                        label: AppStrings.supportYourEmail,
                        icon: Icons.alternate_email),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRegex.hasMatch(s)) return AppStrings.supportInvalidEmail;
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: subjectCtrl,
                    decoration: _supportInputDecoration(ctx,
                        label: AppStrings.supportSubject, icon: Icons.title),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: bodyCtrl,
                    maxLines: 6,
                    decoration: _supportInputDecoration(ctx,
                      label: AppStrings.supportDescribeIssue,
                      icon: Icons.description,
                      alignWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.supportReplyEta,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(AppStrings.supportCancel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            if (!(formKey.currentState?.validate() ?? false)) return;
                            final ok = await _launchSupportEmail(
                              fromEmail: emailCtrl.text.trim(),
                              subject: subjectCtrl.text.trim(),
                              issue: bodyCtrl.text.trim(),
                            );
                            if (ok && ctx.mounted) Navigator.of(ctx).pop();
                            if (!ok && ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(AppStrings.supportOpenEmailFailed)),
                              );
                            }
                          },
                          label: Text(AppStrings.supportSend),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<bool> _launchSupportEmail({
  required String fromEmail,
  required String subject,
  required String issue,
}) async {
  final body = 'From: ' + fromEmail + '\n\n' + issue;
  final encodedSubject = Uri.encodeComponent(
    subject.isEmpty ? AppStrings.supportDefaultSubject : subject,
  );
  final encodedBody = Uri.encodeComponent(body);
  final uri = Uri.parse(
    'mailto:' + AppStrings.supportEmail + '?subject=' + encodedSubject + '&body=' + encodedBody,
  );

  if (await canLaunchUrl(uri)) {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<HelpArticle> _suggestions = const [];
  static const Duration _animDur = Duration(milliseconds: 200);
  bool _showOverlay = false;
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // If a target article id is provided, open it after first frame
    if (widget.openArticleId != null && widget.openArticleId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final art = HelpArticlesRepo.byId(widget.openArticleId!);
        if (art != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ArticleDetailScreen(article: art),
            ),
          );
        }
      });
    }
  }

  void _runLiveSearch(String q) {
    final trimmed = q.trim();
    setState(() {
      _suggestions =
          trimmed.isEmpty
              ? const []
              : HelpArticlesRepo.search(trimmed).take(5).toList();
      _showOverlay = trimmed.isNotEmpty;
    });
  }

  void _hideOverlay() {
    if (_showOverlay) {
      setState(() => _showOverlay = false);
    }
  }

  void _openArticleByTitle(String title) {
    final art = HelpArticlesRepo.all.firstWhere(
      (a) => a.title == title,
      orElse:
          () => HelpArticle(
            id: 'custom',
            title: title,
            category: '',
            body: AppStrings.helpUnderDevelopment,
          ),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ArticleDetailScreen(article: art)),
    );
  }

  void _openAllArticles({String query = ''}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ArticleListScreen(initialQuery: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          AppStrings.helpCenter,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main scrollable content
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is UserScrollNotification ||
                      notification is ScrollUpdateNotification) {
                    _hideOverlay();
                  }
                  return false;
                },
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    // Search Bar
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          decoration: InputDecoration(
                            hintText: AppStrings.helpSearchPlaceholder,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon:
                                _searchCtrl.text.trim().isEmpty
                                    ? null
                                    : Padding(
                                      padding: const EdgeInsets.only(
                                        right: 6.0,
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        clipBehavior: Clip.antiAlias,
                                        child: IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            _runLiveSearch('');
                                            _hideOverlay();
                                            FocusScope.of(context).unfocus();
                                          },
                                          tooltip: 'Clear',
                                        ),
                                      ),
                                    ),
                            filled: true,
                            fillColor: isDark ? Colors.grey[900] : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                              borderSide: BorderSide(
                                color: Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                              borderSide: BorderSide(
                                color: Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: _runLiveSearch,
                          onChanged: _runLiveSearch,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Categories Grid
                    _SectionTitle(title: AppStrings.helpCategories),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // 2 columns on narrow screens, 4 on wide
                        final isWide = constraints.maxWidth > 720;
                        final crossAxisCount = isWide ? 4 : 2;
                        // Use a fixed mainAxisExtent on small screens to ensure enough vertical space.
                        // Make it responsive to text scale factor to avoid overflow with larger fonts.
                        final tsf = MediaQuery.of(context).textScaleFactor;
                        final baseExtent = isWide ? 154.0 : 170.0;
                        final mainAxisExtent =
                            baseExtent *
                            (tsf > 1.1 ? tsf.clamp(1.0, 1.25) : 1.0);

                        final items = [
                          _CategoryCard(
                            icon: AppIcons.smsSecurity,
                            title: AppStrings.helpCatSmsSecurity,
                            links: const [
                              AppStrings.helpQuickSmsSecurityGuide,
                              AppStrings.helpQuickEnableSmsScanning,
                              AppStrings.helpQuickWhatIsAutoLinkScan,
                            ],
                            onLinkTap: _openArticleByTitle,
                          ),
                          _CategoryCard(
                            icon: AppIcons.deviceSecurity,
                            title: AppStrings.helpCatDeviceSecurity,
                            links: const [
                              AppStrings.helpQuickDeviceSecurityGuide,
                              AppStrings.helpQuickRecommendationAction,
                              AppStrings.helpQuickMaliciousApps,
                            ],
                            onLinkTap: _openArticleByTitle,
                          ),
                          _CategoryCard(
                            icon: AppIcons.webSecurity,
                            title: AppStrings.helpCatWebSecurity,
                            links: const [
                              AppStrings.helpQuickWebSecurityGuide,
                              AppStrings.helpQuickWebFilteringExplained,
                              AppStrings.helpQuickUniversalDnsFiltering,
                            ],
                            onLinkTap: _openArticleByTitle,
                          ),
                          _CategoryCard(
                            icon: AppIcons.settings,
                            title: AppStrings.helpCatOthers,
                            links: const [
                              AppStrings.helpQuickSettingsGuide,
                              AppStrings.helpQuickContactSupport,
                            ],
                            onLinkTap: _openArticleByTitle,
                          ),
                        ];

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: mainAxisExtent,
                              ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final it = items[index];
                            return it;
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    _SectionTitle(title: AppStrings.helpLatestArticles),
                    const SizedBox(height: 8),

                    // Featured articles list
                    _ArticleTile(
                      title: AppStrings.helpQuickEnableSmsScanning,
                      onTap:
                          () => _openArticleByTitle(
                            AppStrings.helpQuickEnableSmsScanning,
                          ),
                    ),
                    _ArticleTile(
                      title: AppStrings.helpArtBlockedWebsitesWhitelist,
                      onTap:
                          () => _openArticleByTitle(
                            AppStrings.helpArtBlockedWebsitesWhitelist,
                          ),
                    ),
                    _ArticleTile(
                      title: AppStrings.helpQuickPerAppDnsFiltering,
                      onTap:
                          () => _openArticleByTitle(
                            AppStrings.helpQuickPerAppDnsFiltering,
                          ),
                    ),
                    _ArticleTile(
                      title: AppStrings.helpWhyDomainFilterNotWorking,
                      onTap:
                          () => _openArticleByTitle(
                            AppStrings.helpWhyDomainFilterNotWorking,
                          ),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            () => _openAllArticles(query: _searchCtrl.text),
                        child: Text(
                          AppStrings.helpSeeAll,
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            AppStrings.helpDidntFind,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _showContactSupportSheet(context),
                            icon: const Icon(AppIcons.support),
                            label: Text(AppStrings.helpContactSupport),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tap-outside dismiss layer (below overlay, above content)
            if (_showOverlay && _searchCtrl.text.trim().isNotEmpty)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    _hideOverlay();
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),

            // Floating suggestions overlay (does not occupy layout space)
            if (_showOverlay && _searchCtrl.text.trim().isNotEmpty)
              Positioned(
                left: 14,
                right: 14,
                top: 14 + 56 + 8, // page padding + approx. field height + gap
                child: Material(
                  elevation: 6,
                  color: isDark ? Colors.grey[900] : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.grey.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 3,
                        color: AppTheme.primaryColor.withOpacity(0.9),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                AppStrings.helpResultsFor(
                                  _searchCtrl.text.trim(),
                                ),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            if (_suggestions.isNotEmpty)
                              Text(
                                _suggestions.length.toString(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      if (_suggestions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Text(AppStrings.helpNoResults),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: Scrollbar(
                            child: ListView.separated(
                              shrinkWrap: true,
                              primary: false,
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                              itemBuilder:
                                  (context, i) => _ArticleTile(
                                    title: _suggestions[i].title,
                                    onTap:
                                        () => _openArticleByTitle(
                                          _suggestions[i].title,
                                        ),
                                  ),
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemCount: _suggestions.length,
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                          child: TextButton(
                            onPressed:
                                () => _openAllArticles(query: _searchCtrl.text),
                            child: Text(
                              AppStrings.helpSeeMore,
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArticleSectionCard extends StatelessWidget {
  final HelpSection section;
  final bool isDark;
  final int? index;

  const _ArticleSectionCard({required this.section, required this.isDark, this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDark ? Colors.grey[900] : Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.imageAsset.isNotEmpty)
            Container(
              color: isDark ? Colors.black : Colors.grey[100],
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(section.imageAsset, fit: BoxFit.contain),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index != null)
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      index.toString(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                if (index != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              section.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> links;
  final void Function(String title) onLinkTap;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.links,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? Colors.grey[900] : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      // ensure ripple clips to rounded card
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcons.getFeatureIcon(icon, context: context),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            ...links
                .take(3)
                .map(
                  (l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias, // clip ripple to pill shape
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onLinkTap(l),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 1.0,
                            horizontal: 6.0,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.chevron_right, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  l,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _ArticleTile({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? Colors.grey[900] : Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      // clip ListTile ripple to rounded shape
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// All articles list screen with search
class _ArticleListScreen extends StatefulWidget {
  final String initialQuery;

  const _ArticleListScreen({this.initialQuery = ''});

  @override
  State<_ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<_ArticleListScreen> {
  late TextEditingController _ctrl;
  late List<HelpArticle> _results;

  void _runSearch(String q) {
    setState(() {
      _results = HelpArticlesRepo.search(q);
    });
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _results = HelpArticlesRepo.search(widget.initialQuery);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          AppStrings.helpAllArticles,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      backgroundColor: bgColor,
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Search field
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: AppStrings.helpSearchPlaceholder,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: isDark ? Colors.grey[900] : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: _runSearch,
            onSubmitted: _runSearch,
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 12),
          if ((_ctrl.text).trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                AppStrings.helpResultsFor(_ctrl.text.trim()),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          if (_results.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(AppStrings.helpNoResults),
              ),
            )
          else
            ..._results.map(
              (a) => _ArticleTile(
                title: a.title,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ArticleDetailScreen(article: a),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Simple article detail screen with placeholder body
class _ArticleDetailScreen extends StatelessWidget {
  final HelpArticle article;

  const _ArticleDetailScreen({required this.article});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppTheme.sheetBackgroundDark : AppTheme.sheetBackgroundLight;
    final related = HelpArticlesRepo.relatedTo(article);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          article.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      backgroundColor: bgColor,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(article.category, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if ((article.sections ?? []).isEmpty)
            Card(
              color: isDark ? Colors.grey[900] : Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  article.body.isEmpty
                      ? AppStrings.helpUnderDevelopment
                      : article.body,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.5),
                ),
              ),
            )
          else
            ...((article.sections ?? [])
                .asMap()
                .entries
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: _ArticleSectionCard(
                      section: e.value,
                      isDark: isDark,
                      index: e.key + 1,
                    ),
                  ),
                )),
          if (related.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              AppStrings.helpRelatedArticles,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...related.map(
              (a) => _ArticleTile(
                title: a.title,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ArticleDetailScreen(article: a),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
