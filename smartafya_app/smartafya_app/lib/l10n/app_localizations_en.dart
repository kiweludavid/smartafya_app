// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSwahili => 'Kiswahili';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get loginSubtitle => 'Your Mental Health Matters';

  @override
  String get email => 'Email';

  @override
  String get emailHelper => 'Use your account email';

  @override
  String get pleaseEnterEmail => 'Please enter your email.';

  @override
  String get enterValidEmail => 'Enter a valid email address.';

  @override
  String get password => 'Password';

  @override
  String get passwordHelper => 'At least 8 characters';

  @override
  String get pleaseEnterPassword => 'Please enter your password.';

  @override
  String get passwordMinLength => 'Password must be at least 8 characters.';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get login => 'Login';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String get signUp => 'Sign Up';

  @override
  String get loginFailed => 'Login failed. Please try again.';

  @override
  String get retry => 'Retry';

  @override
  String get continueAction => 'Continue';

  @override
  String get open => 'Open';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get reschedule => 'Reschedule';

  @override
  String get navHome => 'Home';

  @override
  String get navChat => 'Chat';

  @override
  String get navAppointments => 'Appointments';

  @override
  String get navProfile => 'Profile';

  @override
  String get roleClient => 'Client';

  @override
  String get roleDoctor => 'Doctor';

  @override
  String get couldNotLoadHomeData => 'Could not load home data.';

  @override
  String get couldNotLoadProfileRetry =>
      'Could not load your profile. Please retry.';

  @override
  String get homeLoadTimedOut => 'Home load timed out. Please retry.';

  @override
  String get couldNotLoadHomeRetry => 'Could not load home. Please retry.';

  @override
  String get couldNotLoadSessionsPullToRetry =>
      'Could not load sessions. Pull down to retry.';

  @override
  String get couldNotLoadAllDataPullToRetry =>
      'Could not load all data. Pull down to retry.';

  @override
  String get couldNotLoadHomeDataPullToRetry =>
      'Could not load your home data. Pull to retry.';

  @override
  String get sessionLinkNotAvailable => 'Session link not available yet';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get greetingThere => 'there';

  @override
  String greetingWithName(String greeting, String name) {
    return '$greeting, $name 👋';
  }

  @override
  String get careTodaySummary => 'Here\'s everything for your care today.';

  @override
  String get hello => 'Hello';

  @override
  String helloName(String name) {
    return 'Hello, $name';
  }

  @override
  String get doctorThankYou => 'Thank you for supporting clients today.';

  @override
  String get howAreYouFeeling => 'How are you feeling today?';

  @override
  String get upcomingSession => 'Upcoming Session';

  @override
  String get startYourCare => 'Start your care';

  @override
  String get bookFirstConsultation => 'Book your first consultation';

  @override
  String get consultation => 'Consultation';

  @override
  String get joinSession => 'Join Session';

  @override
  String get bookConsultation => 'Book Consultation';

  @override
  String get videoConsultation => 'Video Consultation';

  @override
  String get audioConsultation => 'Audio Consultation';

  @override
  String get physicalConsultation => 'Physical Consultation';

  @override
  String get onlineConsultation => 'Online consultation';

  @override
  String get audioConsultationLower => 'Audio consultation';

  @override
  String get inPersonVisit => 'In-person visit';

  @override
  String setupYourCare(int completed, int total) {
    return 'Setup your care ($completed/$total completed)';
  }

  @override
  String get fillHealthForm => 'Fill health form';

  @override
  String get bookSession => 'Book session';

  @override
  String get makePayment => 'Make payment';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get quickActionsLower => 'Quick actions';

  @override
  String get more => 'More';

  @override
  String get bookConsultationSubtitle => 'Start a new session';

  @override
  String get myAppointments => 'My Appointments';

  @override
  String get viewSchedule => 'View schedule';

  @override
  String get scheduleWithSpecialist => 'Schedule with a specialist';

  @override
  String get viewAndManage => 'View & manage';

  @override
  String get joinSessionSubtitle => 'Open session link';

  @override
  String get chatSubtitle => 'Your conversations';

  @override
  String get medicalRecords => 'Medical Records';

  @override
  String get yourHistory => 'Your history';

  @override
  String sessionCreditBanner(String amount) {
    return 'You have a session credit of $amount from a first missed visit. It will apply toward your next eligible paid session.';
  }

  @override
  String get youMissedSession => 'You missed a session';

  @override
  String withDoctor(String name) {
    return 'With $name';
  }

  @override
  String get getHelp => 'Get help';

  @override
  String sessionPosition(int current, int total) {
    return 'Session $current of $total';
  }

  @override
  String get startNewConsultation => 'Start New Consultation';

  @override
  String get noUpcomingAppointments => 'No upcoming appointments';

  @override
  String get bookConsultationToStart => 'Book a consultation to get started.';

  @override
  String get continueConversation => 'Continue Conversation';

  @override
  String get chatWithSpecialist => 'Chat with your specialist';

  @override
  String get recently => 'Recently';

  @override
  String get doctorLabel => 'Doctor';

  @override
  String get specialtyLabel => 'Specialty';

  @override
  String get sessionLabel => 'Session';

  @override
  String get dateTimeLabel => 'Date & Time';

  @override
  String get viewDetails => 'View Details';

  @override
  String get joinNow => 'Join Now';

  @override
  String get specialistAssigned => 'Specialist assigned';

  @override
  String get awaitingMatch => 'Awaiting match';

  @override
  String get mentalHealthSpecialist => 'Mental health specialist';

  @override
  String get waitingForSpecialist => 'Waiting for specialist confirmation.';

  @override
  String get verifyingPayment =>
      'Verifying your payment — we\'ll notify you shortly.';

  @override
  String sessionStartsInMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return 'Your session starts in $_temp0.';
  }

  @override
  String sessionStartsInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return 'Your session starts in $_temp0.';
  }

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusInReview => 'In Review';

  @override
  String get statusAwaitingPayment => 'Awaiting Payment';

  @override
  String get statusPending => 'Pending';

  @override
  String get tbd => 'TBD';

  @override
  String get emDash => '—';
}
