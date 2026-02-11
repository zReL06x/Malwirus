 import 'package:flutter/material.dart';
 import '../../strings.dart';
 import '../theme.dart';
 import '../icons.dart';

 /// Feature type selection for the note dialog.
 enum FeatureType { sms, device, web }

 /// A responsive popup dialog showing user-friendly notes for a feature.
 ///
 /// Use FeatureNoteDialog.show(context, FeatureType.sms) to open.
 class FeatureNoteDialog extends StatelessWidget {
   final FeatureType feature;

   const FeatureNoteDialog({Key? key, required this.feature}) : super(key: key);

   static Future<void> show(BuildContext context, FeatureType feature) {
     return showDialog(
       context: context,
       barrierDismissible: true,
       builder: (_) => FeatureNoteDialog(feature: feature),
     );
   }

   @override
   Widget build(BuildContext context) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     final bg = AppTheme.dialogBackground(isDark);
     final title = _titleFor(feature);
     final icon = _iconFor(feature);
     final data = _dataFor(feature);
     final how = _howFor(feature);
     final privacy = _privacyFor(feature);

     // Responsive width capping for tablets/landscape
     final maxWidth = 560.0; // comfortable reading width

     return AlertDialog(
       backgroundColor: bg,
       insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
       contentPadding: EdgeInsets.zero,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       content: ConstrainedBox(
         constraints: BoxConstraints(
           maxWidth: maxWidth,
           // Height adapts to content; scroll when needed
         ),
         child: _DialogBody(
           title: title,
           icon: icon,
           sections: [
             _NoteSection(
               heading: AppStrings.featureNoteWhatData,
               body: data,
               icon: Icons.dataset_linked,
             ),
             _NoteSection(
               heading: AppStrings.featureNoteHowItWorks,
               body: how,
               icon: Icons.info_outline,
             ),
             _NoteSection(
               heading: AppStrings.featureNotePrivacy,
               body: privacy,
               icon: AppIcons.privacy,
             ),
           ],
         ),
       ),
       actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(context).maybePop(),
           child: Text(AppStrings.close),
         ),
       ],
     );
   }

   String _titleFor(FeatureType f) {
     switch (f) {
       case FeatureType.sms:
         return AppStrings.featureNoteSmsTitle;
       case FeatureType.device:
         return AppStrings.featureNoteDeviceTitle;
       case FeatureType.web:
         return AppStrings.featureNoteWebTitle;
     }
   }

   IconData _iconFor(FeatureType f) {
     switch (f) {
       case FeatureType.sms:
         return AppIcons.smsSecurity;
       case FeatureType.device:
         return AppIcons.deviceSecurity;
       case FeatureType.web:
         return AppIcons.webSecurity;
     }
   }

   String _dataFor(FeatureType f) {
     switch (f) {
       case FeatureType.sms:
         return AppStrings.featureNoteSmsData;
       case FeatureType.device:
         return AppStrings.featureNoteDeviceData;
       case FeatureType.web:
         return AppStrings.featureNoteWebData;
     }
   }

   String _howFor(FeatureType f) {
     switch (f) {
       case FeatureType.sms:
         return AppStrings.featureNoteSmsHow;
       case FeatureType.device:
         return AppStrings.featureNoteDeviceHow;
       case FeatureType.web:
         return AppStrings.featureNoteWebHow;
     }
   }

   String _privacyFor(FeatureType f) {
     switch (f) {
       case FeatureType.sms:
         return AppStrings.featureNoteSmsPrivacy;
       case FeatureType.device:
         return AppStrings.featureNoteDevicePrivacy;
       case FeatureType.web:
         return AppStrings.featureNoteWebPrivacy;
     }
   }
 }

 class _DialogBody extends StatelessWidget {
   final String title;
   final IconData icon;
   final List<_NoteSection> sections;

   const _DialogBody({
     Key? key,
     required this.title,
     required this.icon,
     required this.sections,
   }) : super(key: key);

   @override
   Widget build(BuildContext context) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     return Column(
       mainAxisSize: MainAxisSize.min,
       crossAxisAlignment: CrossAxisAlignment.stretch,
       children: [
         // Header
         Padding(
           padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
           child: Row(
             children: [
               Icon(icon, color: isDark ? Colors.white : Colors.black),
               const SizedBox(width: 8),
               Expanded(
                 child: Text(
                   title,
                   style: TextStyle(
                     fontSize: 20,
                     fontWeight: FontWeight.bold,
                     color: isDark ? Colors.white : Colors.black,
                   ),
                 ),
               ),
             ],
           ),
         ),
         const Divider(height: 1),
         Flexible(
           child: SingleChildScrollView(
             padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                 for (final s in sections) ...[
                   s,
                   const SizedBox(height: 16),
                 ],
               ],
             ),
           ),
         ),
       ],
     );
   }
 }

 class _NoteSection extends StatelessWidget {
   final String heading;
   final String body;
   final IconData icon;

   const _NoteSection({
     Key? key,
     required this.heading,
     required this.body,
     required this.icon,
   }) : super(key: key);

   @override
   Widget build(BuildContext context) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Row(
           children: [
             Icon(icon, size: 18, color: isDark ? Colors.white70 : Colors.black87),
             const SizedBox(width: 6),
             Text(
               heading,
               style: TextStyle(
                 fontSize: 14,
                 fontWeight: FontWeight.w600,
                 color: isDark ? Colors.white : Colors.black,
               ),
             ),
           ],
         ),
         const SizedBox(height: 6),
         Text(
           body,
           style: TextStyle(
             fontSize: 14,
             height: 1.4,
             color: isDark ? Colors.white70 : Colors.black87,
           ),
         ),
       ],
     );
   }
 }
