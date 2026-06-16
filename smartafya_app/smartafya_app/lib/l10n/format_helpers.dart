import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:smart_afya/l10n/app_localizations.dart';

String localizedSessionType(AppLocalizations l10n, String? sessionType, {bool compact = false}) {
  final s = (sessionType ?? '').toLowerCase().trim();
  if (compact) {
    if (s == 'video' || s == 'online') return l10n.onlineConsultation;
    if (s == 'audio') return l10n.audioConsultationLower;
    if (s == 'physical') return l10n.inPersonVisit;
    return l10n.consultation;
  }
  if (s == 'video') return l10n.videoConsultation;
  if (s == 'audio') return l10n.audioConsultation;
  if (s == 'physical') return l10n.physicalConsultation;
  return l10n.consultation;
}

String formatScheduledDateTime(BuildContext context, DateTime? dt) {
  final l10n = AppLocalizations.of(context)!;
  if (dt == null) return l10n.tbd;
  final locale = Localizations.localeOf(context).toString();
  final date = DateFormat('d MMM', locale).format(dt);
  final time = DateFormat('h:mm a', locale).format(dt);
  return '$date \u2022 $time';
}

String formatScheduledWhenLong(BuildContext context, DateTime? dt) {
  if (dt == null) return '';
  final locale = Localizations.localeOf(context).toString();
  return DateFormat('EEE, dd MMM yyyy  \u2022  h:mm a', locale).format(dt);
}

String formatShortWhen(BuildContext context, String? iso) {
  final l10n = AppLocalizations.of(context)!;
  final dt = DateTime.tryParse(iso ?? '')?.toLocal();
  if (dt == null) return l10n.recently;
  final locale = Localizations.localeOf(context).toString();
  return DateFormat('MMM d, yyyy \u00b7 h:mm a', locale).format(dt);
}

String timeGreeting(AppLocalizations l10n, DateTime now) {
  final h = now.hour;
  if (h < 12) return l10n.goodMorning;
  if (h < 18) return l10n.goodAfternoon;
  return l10n.goodEvening;
}
