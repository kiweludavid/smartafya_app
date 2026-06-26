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
  String get signupSubtitle =>
      'Create your account and start your mental wellness journey';

  @override
  String get accountCreatedSuccessfully => 'Account created successfully.';

  @override
  String get signupFailed => 'Sign up failed. Please try again.';

  @override
  String get fullName => 'Full Name';

  @override
  String get fullNameHelper => 'Use your real name for your profile';

  @override
  String get pleaseEnterFullName => 'Please enter your full name.';

  @override
  String get nameMinLength => 'Name should be at least 3 characters.';

  @override
  String get emailSignupHelper => 'We will send verification to this email';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get phoneHelper => 'Include country code (e.g. +255...)';

  @override
  String get pleaseEnterPhone => 'Please enter your phone number.';

  @override
  String get enterValidPhone => 'Enter a valid phone number.';

  @override
  String get passwordSignupHelper =>
      '8+ chars, 1 uppercase, 1 special character';

  @override
  String get passwordStrengthHint =>
      'Use 8+ chars with 1 uppercase and 1 special character.';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get confirmPasswordHelper => 'Re-enter your password';

  @override
  String get pleaseConfirmPassword => 'Please confirm your password.';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get role => 'Role';

  @override
  String get specialistType => 'Specialist Type';

  @override
  String get specialistTypeHelper => 'Required for doctor accounts';

  @override
  String get pleaseSelectSpecialistType =>
      'Please select your specialist type.';

  @override
  String get psychologist => 'Psychologist';

  @override
  String get psychiatrist => 'Psychiatrist';

  @override
  String get therapist => 'Therapist';

  @override
  String get cleric => 'Cleric';

  @override
  String get influencer => 'Influencer';

  @override
  String get doctor => 'Doctor';

  @override
  String get client => 'Client';

  @override
  String get appointmentsTitle => 'Appointments';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get completed => 'Completed';

  @override
  String get missed => 'Missed';

  @override
  String get failedToLoad => 'Failed to load.';

  @override
  String actionRequiredCount(int count) {
    return 'Action required ($count)';
  }

  @override
  String get careActionsBlurb =>
      'Your specialist requested a transfer or is unavailable. Tap to choose: transfer or reschedule.';

  @override
  String get tapToResolveTransferReschedule =>
      'Tap to resolve transfer/reschedule';

  @override
  String get followUpRequested => 'Follow-up requested';

  @override
  String get suggestedDateDash => 'Suggested date: —';

  @override
  String suggestedDateValue(String date) {
    return 'Suggested date: $date';
  }

  @override
  String get doctorRecommendedAnotherSession =>
      'Doctor recommended another session';

  @override
  String get tapToChooseAvailabilityProceed =>
      'Tap to choose your availability & proceed.';

  @override
  String get followUpInitialDescription =>
      'Follow-up session requested by doctor.';

  @override
  String get followUpBookingSubmitted => 'Follow-up booking submitted.';

  @override
  String get pendingRequests => 'Pending requests';

  @override
  String get allBookingsCoordination => 'All bookings (coordination)';

  @override
  String bookingStatusTitle(String status) {
    return 'Booking · $status';
  }

  @override
  String bookingTypePreferred(String type, String preferred) {
    return 'Type: $type\nPreferred: $preferred';
  }

  @override
  String get noUpcomingAppointments => 'No upcoming appointments';

  @override
  String get noMissedSessions => 'No missed sessions';

  @override
  String get noCompletedAppointmentsYet => 'No completed appointments yet';

  @override
  String get bookConsultationToGetStarted =>
      'Book a consultation to get started.';

  @override
  String get missedSessionsInfo =>
      'When a session is marked missed, it will appear here. You can reschedule anytime.';

  @override
  String get finishedConsultationsInfo => 'Finished consultations appear here.';

  @override
  String get bookAConsultation => 'Book a consultation';

  @override
  String get tbdShort => 'TBD';

  @override
  String get specialistAssignedShort => 'Specialist assigned';

  @override
  String get awaitingSpecialist => 'Awaiting specialist';

  @override
  String get ctaView => 'View';

  @override
  String get ctaReschedule => 'Reschedule';

  @override
  String get ctaPay => 'Pay';

  @override
  String get ctaJoin => 'Join';

  @override
  String get ctaFeedback => 'Feedback';

  @override
  String get paymentPaid => 'Paid';

  @override
  String get paymentInReview => 'In review';

  @override
  String get paymentNeeded => 'Pay needed';

  @override
  String get bookingIntro =>
      'Complete the details below. Your answers help us match you and prepare for your session.';

  @override
  String get termsAndConditions => 'Terms & Conditions';

  @override
  String get termsBody =>
      'By submitting this form, you confirm that the information you provide is accurate to the best of your knowledge. Your responses may be reviewed by your assigned care team to help prepare for your session. If you are experiencing an emergency, contact local emergency services immediately.';

  @override
  String lastAccepted(String timestamp) {
    return 'Last accepted: $timestamp';
  }

  @override
  String get acceptTermsContinue => 'Accept Terms & Continue';

  @override
  String get viewTerms => 'View Terms & Conditions';

  @override
  String get acceptTermsToEnableSubmission =>
      'Accept the Terms & Conditions above to enable submission.';

  @override
  String get availabilityConfirmation => 'Availability confirmation';

  @override
  String get confirmAttendSelectedTimes =>
      'I confirm I can attend at the selected times.';

  @override
  String get confirmAvailabilityToEnable =>
      'Confirm availability to enable submission.';

  @override
  String get stateOfMind => 'State of mind';

  @override
  String get describeCurrentConcerns => 'Describe your current concerns';

  @override
  String get pleaseAddMoreDetail =>
      'Please add more detail (at least a short paragraph).';

  @override
  String get whoShouldAttendYou => 'Who should attend you?';

  @override
  String get whoShouldAttendHelp =>
      'Pick a specific psychologist, psychiatrist, therapist, faith leader, or even a known mental-health influencer. Don’t see your person? Use “Special arrangement” inside the picker.';

  @override
  String get sessionType => 'Session type';

  @override
  String get audio => 'Audio';

  @override
  String get video => 'Video';

  @override
  String get physical => 'Physical';

  @override
  String get sessionTypeVisitSite => 'Session type (visit site)';

  @override
  String get homeVisit => 'Home visit';

  @override
  String get officeClinic => 'Office / clinic';

  @override
  String get duration => 'Duration';

  @override
  String get preferredDatesTimes => 'Preferred dates & times (at least 3)';

  @override
  String get preferredDatesHelp =>
      'Add at least 3 slots on different calendar days. Each slot uses your chosen duration as the session length.';

  @override
  String get addSlot => 'Add slot';

  @override
  String get visitLocation => 'Visit location';

  @override
  String get visitLocationHelp => 'Where should your care team meet you?';

  @override
  String get street => 'Street';

  @override
  String get streetHint => 'e.g. Masaki Peninsula, Plot 12';

  @override
  String get enterStreetOrArea => 'Enter your street or area.';

  @override
  String get city => 'City';

  @override
  String get cityHint => 'e.g. Dar es Salaam';

  @override
  String get enterCity => 'Enter your city.';

  @override
  String get selectedSpecialist => 'Selected specialist';

  @override
  String get lockedForThisBooking => 'Locked for this booking';

  @override
  String get chooseYourSpecialist => 'Choose your specialist';

  @override
  String get browseSpecialistsHelp =>
      'Browse psychologists, clerics, influencers and more — or let Smart Afya match you.';

  @override
  String get smartAfyaMatch => 'Smart Afya match';

  @override
  String get nextAvailableSpecialist =>
      'Next available specialist that fits your profile';

  @override
  String get smartAfyaSpecialist => 'Smart Afya specialist';

  @override
  String get specialArrangement => 'Special arrangement';

  @override
  String get adminWillCoordinate => 'admin will coordinate';

  @override
  String get noPreference => 'No preference';

  @override
  String get matchAnyoneAvailable =>
      'Smart Afya will match you with anyone available';

  @override
  String get change => 'Change';

  @override
  String get clear => 'Clear';

  @override
  String get physicalPriceNegotiable =>
      'Physical session price is negotiable (admin + client).';

  @override
  String estimatedPrice(String price) {
    return 'Estimated price: $price';
  }

  @override
  String get submitBooking => 'Submit booking';

  @override
  String get acceptTermsToSubmit => 'Accept Terms to submit';

  @override
  String get confirmAvailabilityToSubmit => 'Confirm availability to submit';

  @override
  String get add3PreferredDatesToContinue =>
      'Add 3 preferred dates to continue';

  @override
  String get completePaymentToSubmit => 'Complete payment to submit';

  @override
  String get paymentReceived => 'Payment received';

  @override
  String get paymentRequired => 'Payment required';

  @override
  String get canSubmitBookingNow =>
      'You can submit your booking request now. Admin will confirm and schedule.';

  @override
  String payBeforeSubmitting(String price) {
    return 'Pay $price before submitting. Upload proof or complete mobile money / bank transfer.';
  }

  @override
  String get payNow => 'Pay now';

  @override
  String get mustAcceptTermsBeforeContinuing =>
      'You must accept Terms & Conditions before continuing.';

  @override
  String get consentTimestampMissing =>
      'Consent timestamp missing. Please accept Terms & Conditions again.';

  @override
  String get pleaseConfirmAvailabilityBeforeContinuing =>
      'Please confirm your availability before continuing.';

  @override
  String get pleaseAdd3PreferredSlots =>
      'Please add at least 3 preferred slots on different days.';

  @override
  String get selectHomeOrOfficePhysicalVisit =>
      'Select home or office for the physical visit.';

  @override
  String get couldNotStartPaymentTryAgain =>
      'Could not start payment. Please try again.';

  @override
  String get paymentRecordedSubmitNow =>
      'Payment recorded. You can submit your booking now.';

  @override
  String get couldNotStartPayment => 'Could not start payment.';

  @override
  String get maxPreferredSlots => 'You can add up to 6 preferred slots.';

  @override
  String get appointmentDetailsTitle => 'Appointment details';

  @override
  String get timeToBeConfirmed => 'Time to be confirmed';

  @override
  String get specialistPendingAssignment => 'Specialist · pending assignment';

  @override
  String get couldNotOpenSessionLink => 'Could not open the session link';

  @override
  String get cancelThisAppointmentTitle => 'Cancel this appointment?';

  @override
  String get cancelThisAppointmentBody =>
      'Your specialist will be notified. You can re-book any time afterwards.';

  @override
  String get keep => 'Keep';

  @override
  String get cancelAppointment => 'Cancel appointment';

  @override
  String get couldNotCancelTryAgain => 'Could not cancel — please try again.';

  @override
  String get appointmentSection => 'Appointment';

  @override
  String get dateLabel => 'Date';

  @override
  String get timeLabel => 'Time';

  @override
  String get typeLabel => 'Type';

  @override
  String get statusLabel => 'Status';

  @override
  String get paymentSection => 'Payment';

  @override
  String get amountLabel => 'Amount';

  @override
  String get setByAdmin => 'Set by admin';

  @override
  String get completePaymentToConfirm =>
      'Complete payment to confirm this session.';

  @override
  String get notesAndInstructions => 'Notes & instructions';

  @override
  String get missedSessionHelp =>
      'You missed this session. Reschedule to keep your care plan on track, or chat with our team if you need help.';

  @override
  String get payAndConfirm => 'Pay & Confirm';

  @override
  String get sessionNotYetJoinable => 'Session not yet joinable';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusMissed => 'Missed';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusScheduled => 'Scheduled';

  @override
  String get statusAwaitingPaymentLower => 'Awaiting payment';

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
