import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSwahili.
  ///
  /// In en, this message translates to:
  /// **'Kiswahili'**
  String get languageSwahili;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your Mental Health Matters'**
  String get loginSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailHelper.
  ///
  /// In en, this message translates to:
  /// **'Use your account email'**
  String get emailHelper;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email.'**
  String get pleaseEnterEmail;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get enterValidEmail;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHelper;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get pleaseEnterPassword;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get passwordMinLength;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @reschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get reschedule;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get navAppointments;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @roleClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get roleClient;

  /// No description provided for @roleDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get roleDoctor;

  /// No description provided for @couldNotLoadHomeData.
  ///
  /// In en, this message translates to:
  /// **'Could not load home data.'**
  String get couldNotLoadHomeData;

  /// No description provided for @couldNotLoadProfileRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile. Please retry.'**
  String get couldNotLoadProfileRetry;

  /// No description provided for @homeLoadTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Home load timed out. Please retry.'**
  String get homeLoadTimedOut;

  /// No description provided for @couldNotLoadHomeRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load home. Please retry.'**
  String get couldNotLoadHomeRetry;

  /// No description provided for @couldNotLoadSessionsPullToRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load sessions. Pull down to retry.'**
  String get couldNotLoadSessionsPullToRetry;

  /// No description provided for @couldNotLoadAllDataPullToRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load all data. Pull down to retry.'**
  String get couldNotLoadAllDataPullToRetry;

  /// No description provided for @couldNotLoadHomeDataPullToRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load your home data. Pull to retry.'**
  String get couldNotLoadHomeDataPullToRetry;

  /// No description provided for @sessionLinkNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Session link not available yet'**
  String get sessionLinkNotAvailable;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @greetingThere.
  ///
  /// In en, this message translates to:
  /// **'there'**
  String get greetingThere;

  /// No description provided for @greetingWithName.
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name} 👋'**
  String greetingWithName(String greeting, String name);

  /// No description provided for @careTodaySummary.
  ///
  /// In en, this message translates to:
  /// **'Here\'s everything for your care today.'**
  String get careTodaySummary;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// No description provided for @helloName.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String helloName(String name);

  /// No description provided for @doctorThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for supporting clients today.'**
  String get doctorThankYou;

  /// No description provided for @howAreYouFeeling.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling today?'**
  String get howAreYouFeeling;

  /// No description provided for @upcomingSession.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Session'**
  String get upcomingSession;

  /// No description provided for @startYourCare.
  ///
  /// In en, this message translates to:
  /// **'Start your care'**
  String get startYourCare;

  /// No description provided for @bookFirstConsultation.
  ///
  /// In en, this message translates to:
  /// **'Book your first consultation'**
  String get bookFirstConsultation;

  /// No description provided for @consultation.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get consultation;

  /// No description provided for @joinSession.
  ///
  /// In en, this message translates to:
  /// **'Join Session'**
  String get joinSession;

  /// No description provided for @bookConsultation.
  ///
  /// In en, this message translates to:
  /// **'Book Consultation'**
  String get bookConsultation;

  /// No description provided for @videoConsultation.
  ///
  /// In en, this message translates to:
  /// **'Video Consultation'**
  String get videoConsultation;

  /// No description provided for @audioConsultation.
  ///
  /// In en, this message translates to:
  /// **'Audio Consultation'**
  String get audioConsultation;

  /// No description provided for @physicalConsultation.
  ///
  /// In en, this message translates to:
  /// **'Physical Consultation'**
  String get physicalConsultation;

  /// No description provided for @onlineConsultation.
  ///
  /// In en, this message translates to:
  /// **'Online consultation'**
  String get onlineConsultation;

  /// No description provided for @audioConsultationLower.
  ///
  /// In en, this message translates to:
  /// **'Audio consultation'**
  String get audioConsultationLower;

  /// No description provided for @inPersonVisit.
  ///
  /// In en, this message translates to:
  /// **'In-person visit'**
  String get inPersonVisit;

  /// No description provided for @setupYourCare.
  ///
  /// In en, this message translates to:
  /// **'Setup your care ({completed}/{total} completed)'**
  String setupYourCare(int completed, int total);

  /// No description provided for @fillHealthForm.
  ///
  /// In en, this message translates to:
  /// **'Fill health form'**
  String get fillHealthForm;

  /// No description provided for @bookSession.
  ///
  /// In en, this message translates to:
  /// **'Book session'**
  String get bookSession;

  /// No description provided for @makePayment.
  ///
  /// In en, this message translates to:
  /// **'Make payment'**
  String get makePayment;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @quickActionsLower.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActionsLower;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @bookConsultationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a new session'**
  String get bookConsultationSubtitle;

  /// No description provided for @myAppointments.
  ///
  /// In en, this message translates to:
  /// **'My Appointments'**
  String get myAppointments;

  /// No description provided for @viewSchedule.
  ///
  /// In en, this message translates to:
  /// **'View schedule'**
  String get viewSchedule;

  /// No description provided for @scheduleWithSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Schedule with a specialist'**
  String get scheduleWithSpecialist;

  /// No description provided for @viewAndManage.
  ///
  /// In en, this message translates to:
  /// **'View & manage'**
  String get viewAndManage;

  /// No description provided for @joinSessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open session link'**
  String get joinSessionSubtitle;

  /// No description provided for @chatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your conversations'**
  String get chatSubtitle;

  /// No description provided for @medicalRecords.
  ///
  /// In en, this message translates to:
  /// **'Medical Records'**
  String get medicalRecords;

  /// No description provided for @yourHistory.
  ///
  /// In en, this message translates to:
  /// **'Your history'**
  String get yourHistory;

  /// No description provided for @sessionCreditBanner.
  ///
  /// In en, this message translates to:
  /// **'You have a session credit of {amount} from a first missed visit. It will apply toward your next eligible paid session.'**
  String sessionCreditBanner(String amount);

  /// No description provided for @youMissedSession.
  ///
  /// In en, this message translates to:
  /// **'You missed a session'**
  String get youMissedSession;

  /// No description provided for @withDoctor.
  ///
  /// In en, this message translates to:
  /// **'With {name}'**
  String withDoctor(String name);

  /// No description provided for @getHelp.
  ///
  /// In en, this message translates to:
  /// **'Get help'**
  String get getHelp;

  /// No description provided for @sessionPosition.
  ///
  /// In en, this message translates to:
  /// **'Session {current} of {total}'**
  String sessionPosition(int current, int total);

  /// No description provided for @startNewConsultation.
  ///
  /// In en, this message translates to:
  /// **'Start New Consultation'**
  String get startNewConsultation;

  /// No description provided for @noUpcomingAppointments.
  ///
  /// In en, this message translates to:
  /// **'No upcoming appointments'**
  String get noUpcomingAppointments;

  /// No description provided for @bookConsultationToStart.
  ///
  /// In en, this message translates to:
  /// **'Book a consultation to get started.'**
  String get bookConsultationToStart;

  /// No description provided for @continueConversation.
  ///
  /// In en, this message translates to:
  /// **'Continue Conversation'**
  String get continueConversation;

  /// No description provided for @chatWithSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Chat with your specialist'**
  String get chatWithSpecialist;

  /// No description provided for @recently.
  ///
  /// In en, this message translates to:
  /// **'Recently'**
  String get recently;

  /// No description provided for @doctorLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get doctorLabel;

  /// No description provided for @specialtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get specialtyLabel;

  /// No description provided for @sessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get sessionLabel;

  /// No description provided for @dateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateTimeLabel;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @joinNow.
  ///
  /// In en, this message translates to:
  /// **'Join Now'**
  String get joinNow;

  /// No description provided for @specialistAssigned.
  ///
  /// In en, this message translates to:
  /// **'Specialist assigned'**
  String get specialistAssigned;

  /// No description provided for @awaitingMatch.
  ///
  /// In en, this message translates to:
  /// **'Awaiting match'**
  String get awaitingMatch;

  /// No description provided for @mentalHealthSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Mental health specialist'**
  String get mentalHealthSpecialist;

  /// No description provided for @waitingForSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Waiting for specialist confirmation.'**
  String get waitingForSpecialist;

  /// No description provided for @verifyingPayment.
  ///
  /// In en, this message translates to:
  /// **'Verifying your payment — we\'ll notify you shortly.'**
  String get verifyingPayment;

  /// No description provided for @sessionStartsInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Your session starts in {count, plural, =1{1 minute} other{{count} minutes}}.'**
  String sessionStartsInMinutes(int count);

  /// No description provided for @sessionStartsInHours.
  ///
  /// In en, this message translates to:
  /// **'Your session starts in {count, plural, =1{1 hour} other{{count} hours}}.'**
  String sessionStartsInHours(int count);

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusInReview.
  ///
  /// In en, this message translates to:
  /// **'In Review'**
  String get statusInReview;

  /// No description provided for @statusAwaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Payment'**
  String get statusAwaitingPayment;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @tbd.
  ///
  /// In en, this message translates to:
  /// **'TBD'**
  String get tbd;

  /// No description provided for @emDash.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get emDash;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
