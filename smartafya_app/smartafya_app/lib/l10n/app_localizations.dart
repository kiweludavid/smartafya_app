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

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account and start your mental wellness journey'**
  String get signupSubtitle;

  /// No description provided for @accountCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully.'**
  String get accountCreatedSuccessfully;

  /// No description provided for @signupFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed. Please try again.'**
  String get signupFailed;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @fullNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Use your real name for your profile'**
  String get fullNameHelper;

  /// No description provided for @pleaseEnterFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name.'**
  String get pleaseEnterFullName;

  /// No description provided for @nameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Name should be at least 3 characters.'**
  String get nameMinLength;

  /// No description provided for @emailSignupHelper.
  ///
  /// In en, this message translates to:
  /// **'We will send verification to this email'**
  String get emailSignupHelper;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @phoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Include country code (e.g. +255...)'**
  String get phoneHelper;

  /// No description provided for @pleaseEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number.'**
  String get pleaseEnterPhone;

  /// No description provided for @enterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number.'**
  String get enterValidPhone;

  /// No description provided for @passwordSignupHelper.
  ///
  /// In en, this message translates to:
  /// **'8+ chars, 1 uppercase, 1 special character'**
  String get passwordSignupHelper;

  /// No description provided for @passwordStrengthHint.
  ///
  /// In en, this message translates to:
  /// **'Use 8+ chars with 1 uppercase and 1 special character.'**
  String get passwordStrengthHint;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @confirmPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get confirmPasswordHelper;

  /// No description provided for @pleaseConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password.'**
  String get pleaseConfirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @specialistType.
  ///
  /// In en, this message translates to:
  /// **'Specialist Type'**
  String get specialistType;

  /// No description provided for @specialistTypeHelper.
  ///
  /// In en, this message translates to:
  /// **'Required for doctor accounts'**
  String get specialistTypeHelper;

  /// No description provided for @pleaseSelectSpecialistType.
  ///
  /// In en, this message translates to:
  /// **'Please select your specialist type.'**
  String get pleaseSelectSpecialistType;

  /// No description provided for @psychologist.
  ///
  /// In en, this message translates to:
  /// **'Psychologist'**
  String get psychologist;

  /// No description provided for @psychiatrist.
  ///
  /// In en, this message translates to:
  /// **'Psychiatrist'**
  String get psychiatrist;

  /// No description provided for @therapist.
  ///
  /// In en, this message translates to:
  /// **'Therapist'**
  String get therapist;

  /// No description provided for @cleric.
  ///
  /// In en, this message translates to:
  /// **'Cleric'**
  String get cleric;

  /// No description provided for @influencer.
  ///
  /// In en, this message translates to:
  /// **'Influencer'**
  String get influencer;

  /// No description provided for @doctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get doctor;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @appointmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointmentsTitle;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missed;

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load.'**
  String get failedToLoad;

  /// No description provided for @actionRequiredCount.
  ///
  /// In en, this message translates to:
  /// **'Action required ({count})'**
  String actionRequiredCount(int count);

  /// No description provided for @careActionsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Your specialist requested a transfer or is unavailable. Tap to choose: transfer or reschedule.'**
  String get careActionsBlurb;

  /// No description provided for @tapToResolveTransferReschedule.
  ///
  /// In en, this message translates to:
  /// **'Tap to resolve transfer/reschedule'**
  String get tapToResolveTransferReschedule;

  /// No description provided for @followUpRequested.
  ///
  /// In en, this message translates to:
  /// **'Follow-up requested'**
  String get followUpRequested;

  /// No description provided for @suggestedDateDash.
  ///
  /// In en, this message translates to:
  /// **'Suggested date: —'**
  String get suggestedDateDash;

  /// No description provided for @suggestedDateValue.
  ///
  /// In en, this message translates to:
  /// **'Suggested date: {date}'**
  String suggestedDateValue(String date);

  /// No description provided for @doctorRecommendedAnotherSession.
  ///
  /// In en, this message translates to:
  /// **'Doctor recommended another session'**
  String get doctorRecommendedAnotherSession;

  /// No description provided for @tapToChooseAvailabilityProceed.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose your availability & proceed.'**
  String get tapToChooseAvailabilityProceed;

  /// No description provided for @followUpInitialDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow-up session requested by doctor.'**
  String get followUpInitialDescription;

  /// No description provided for @followUpBookingSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Follow-up booking submitted.'**
  String get followUpBookingSubmitted;

  /// No description provided for @pendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending requests'**
  String get pendingRequests;

  /// No description provided for @allBookingsCoordination.
  ///
  /// In en, this message translates to:
  /// **'All bookings (coordination)'**
  String get allBookingsCoordination;

  /// No description provided for @bookingStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking · {status}'**
  String bookingStatusTitle(String status);

  /// No description provided for @bookingTypePreferred.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}\nPreferred: {preferred}'**
  String bookingTypePreferred(String type, String preferred);

  /// No description provided for @noUpcomingAppointments.
  ///
  /// In en, this message translates to:
  /// **'No upcoming appointments'**
  String get noUpcomingAppointments;

  /// No description provided for @noMissedSessions.
  ///
  /// In en, this message translates to:
  /// **'No missed sessions'**
  String get noMissedSessions;

  /// No description provided for @noCompletedAppointmentsYet.
  ///
  /// In en, this message translates to:
  /// **'No completed appointments yet'**
  String get noCompletedAppointmentsYet;

  /// No description provided for @bookConsultationToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Book a consultation to get started.'**
  String get bookConsultationToGetStarted;

  /// No description provided for @missedSessionsInfo.
  ///
  /// In en, this message translates to:
  /// **'When a session is marked missed, it will appear here. You can reschedule anytime.'**
  String get missedSessionsInfo;

  /// No description provided for @finishedConsultationsInfo.
  ///
  /// In en, this message translates to:
  /// **'Finished consultations appear here.'**
  String get finishedConsultationsInfo;

  /// No description provided for @bookAConsultation.
  ///
  /// In en, this message translates to:
  /// **'Book a consultation'**
  String get bookAConsultation;

  /// No description provided for @tbdShort.
  ///
  /// In en, this message translates to:
  /// **'TBD'**
  String get tbdShort;

  /// No description provided for @specialistAssignedShort.
  ///
  /// In en, this message translates to:
  /// **'Specialist assigned'**
  String get specialistAssignedShort;

  /// No description provided for @awaitingSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Awaiting specialist'**
  String get awaitingSpecialist;

  /// No description provided for @ctaView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get ctaView;

  /// No description provided for @ctaReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get ctaReschedule;

  /// No description provided for @ctaPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get ctaPay;

  /// No description provided for @ctaJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get ctaJoin;

  /// No description provided for @ctaFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get ctaFeedback;

  /// No description provided for @paymentPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentPaid;

  /// No description provided for @paymentInReview.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get paymentInReview;

  /// No description provided for @paymentNeeded.
  ///
  /// In en, this message translates to:
  /// **'Pay needed'**
  String get paymentNeeded;

  /// No description provided for @bookingIntro.
  ///
  /// In en, this message translates to:
  /// **'Complete the details below. Your answers help us match you and prepare for your session.'**
  String get bookingIntro;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsAndConditions;

  /// No description provided for @termsBody.
  ///
  /// In en, this message translates to:
  /// **'By submitting this form, you confirm that the information you provide is accurate to the best of your knowledge. Your responses may be reviewed by your assigned care team to help prepare for your session. If you are experiencing an emergency, contact local emergency services immediately.'**
  String get termsBody;

  /// No description provided for @lastAccepted.
  ///
  /// In en, this message translates to:
  /// **'Last accepted: {timestamp}'**
  String lastAccepted(String timestamp);

  /// No description provided for @acceptTermsContinue.
  ///
  /// In en, this message translates to:
  /// **'Accept Terms & Continue'**
  String get acceptTermsContinue;

  /// No description provided for @viewTerms.
  ///
  /// In en, this message translates to:
  /// **'View Terms & Conditions'**
  String get viewTerms;

  /// No description provided for @acceptTermsToEnableSubmission.
  ///
  /// In en, this message translates to:
  /// **'Accept the Terms & Conditions above to enable submission.'**
  String get acceptTermsToEnableSubmission;

  /// No description provided for @availabilityConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Availability confirmation'**
  String get availabilityConfirmation;

  /// No description provided for @confirmAttendSelectedTimes.
  ///
  /// In en, this message translates to:
  /// **'I confirm I can attend at the selected times.'**
  String get confirmAttendSelectedTimes;

  /// No description provided for @confirmAvailabilityToEnable.
  ///
  /// In en, this message translates to:
  /// **'Confirm availability to enable submission.'**
  String get confirmAvailabilityToEnable;

  /// No description provided for @stateOfMind.
  ///
  /// In en, this message translates to:
  /// **'State of mind'**
  String get stateOfMind;

  /// No description provided for @describeCurrentConcerns.
  ///
  /// In en, this message translates to:
  /// **'Describe your current concerns'**
  String get describeCurrentConcerns;

  /// No description provided for @pleaseAddMoreDetail.
  ///
  /// In en, this message translates to:
  /// **'Please add more detail (at least a short paragraph).'**
  String get pleaseAddMoreDetail;

  /// No description provided for @whoShouldAttendYou.
  ///
  /// In en, this message translates to:
  /// **'Who should attend you?'**
  String get whoShouldAttendYou;

  /// No description provided for @whoShouldAttendHelp.
  ///
  /// In en, this message translates to:
  /// **'Pick a specific psychologist, psychiatrist, therapist, faith leader, or even a known mental-health influencer. Don’t see your person? Use “Special arrangement” inside the picker.'**
  String get whoShouldAttendHelp;

  /// No description provided for @sessionType.
  ///
  /// In en, this message translates to:
  /// **'Session type'**
  String get sessionType;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @physical.
  ///
  /// In en, this message translates to:
  /// **'Physical'**
  String get physical;

  /// No description provided for @sessionTypeVisitSite.
  ///
  /// In en, this message translates to:
  /// **'Session type (visit site)'**
  String get sessionTypeVisitSite;

  /// No description provided for @homeVisit.
  ///
  /// In en, this message translates to:
  /// **'Home visit'**
  String get homeVisit;

  /// No description provided for @officeClinic.
  ///
  /// In en, this message translates to:
  /// **'Office / clinic'**
  String get officeClinic;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @preferredDatesTimes.
  ///
  /// In en, this message translates to:
  /// **'Preferred dates & times (at least 3)'**
  String get preferredDatesTimes;

  /// No description provided for @preferredDatesHelp.
  ///
  /// In en, this message translates to:
  /// **'Add at least 3 slots on different calendar days. Each slot uses your chosen duration as the session length.'**
  String get preferredDatesHelp;

  /// No description provided for @addSlot.
  ///
  /// In en, this message translates to:
  /// **'Add slot'**
  String get addSlot;

  /// No description provided for @visitLocation.
  ///
  /// In en, this message translates to:
  /// **'Visit location'**
  String get visitLocation;

  /// No description provided for @visitLocationHelp.
  ///
  /// In en, this message translates to:
  /// **'Where should your care team meet you?'**
  String get visitLocationHelp;

  /// No description provided for @street.
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get street;

  /// No description provided for @streetHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Masaki Peninsula, Plot 12'**
  String get streetHint;

  /// No description provided for @enterStreetOrArea.
  ///
  /// In en, this message translates to:
  /// **'Enter your street or area.'**
  String get enterStreetOrArea;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @cityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Dar es Salaam'**
  String get cityHint;

  /// No description provided for @enterCity.
  ///
  /// In en, this message translates to:
  /// **'Enter your city.'**
  String get enterCity;

  /// No description provided for @selectedSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Selected specialist'**
  String get selectedSpecialist;

  /// No description provided for @lockedForThisBooking.
  ///
  /// In en, this message translates to:
  /// **'Locked for this booking'**
  String get lockedForThisBooking;

  /// No description provided for @chooseYourSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Choose your specialist'**
  String get chooseYourSpecialist;

  /// No description provided for @browseSpecialistsHelp.
  ///
  /// In en, this message translates to:
  /// **'Browse psychologists, clerics, influencers and more — or let Smart Afya match you.'**
  String get browseSpecialistsHelp;

  /// No description provided for @smartAfyaMatch.
  ///
  /// In en, this message translates to:
  /// **'Smart Afya match'**
  String get smartAfyaMatch;

  /// No description provided for @nextAvailableSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Next available specialist that fits your profile'**
  String get nextAvailableSpecialist;

  /// No description provided for @smartAfyaSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Smart Afya specialist'**
  String get smartAfyaSpecialist;

  /// No description provided for @specialArrangement.
  ///
  /// In en, this message translates to:
  /// **'Special arrangement'**
  String get specialArrangement;

  /// No description provided for @adminWillCoordinate.
  ///
  /// In en, this message translates to:
  /// **'admin will coordinate'**
  String get adminWillCoordinate;

  /// No description provided for @noPreference.
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get noPreference;

  /// No description provided for @matchAnyoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'Smart Afya will match you with anyone available'**
  String get matchAnyoneAvailable;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @physicalPriceNegotiable.
  ///
  /// In en, this message translates to:
  /// **'Physical session price is negotiable (admin + client).'**
  String get physicalPriceNegotiable;

  /// No description provided for @estimatedPrice.
  ///
  /// In en, this message translates to:
  /// **'Estimated price: {price}'**
  String estimatedPrice(String price);

  /// No description provided for @submitBooking.
  ///
  /// In en, this message translates to:
  /// **'Submit booking'**
  String get submitBooking;

  /// No description provided for @acceptTermsToSubmit.
  ///
  /// In en, this message translates to:
  /// **'Accept Terms to submit'**
  String get acceptTermsToSubmit;

  /// No description provided for @confirmAvailabilityToSubmit.
  ///
  /// In en, this message translates to:
  /// **'Confirm availability to submit'**
  String get confirmAvailabilityToSubmit;

  /// No description provided for @add3PreferredDatesToContinue.
  ///
  /// In en, this message translates to:
  /// **'Add 3 preferred dates to continue'**
  String get add3PreferredDatesToContinue;

  /// No description provided for @completePaymentToSubmit.
  ///
  /// In en, this message translates to:
  /// **'Complete payment to submit'**
  String get completePaymentToSubmit;

  /// No description provided for @paymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get paymentReceived;

  /// No description provided for @paymentRequired.
  ///
  /// In en, this message translates to:
  /// **'Payment required'**
  String get paymentRequired;

  /// No description provided for @canSubmitBookingNow.
  ///
  /// In en, this message translates to:
  /// **'You can submit your booking request now. Admin will confirm and schedule.'**
  String get canSubmitBookingNow;

  /// No description provided for @payBeforeSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Pay {price} before submitting. Upload proof or complete mobile money / bank transfer.'**
  String payBeforeSubmitting(String price);

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get payNow;

  /// No description provided for @mustAcceptTermsBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'You must accept Terms & Conditions before continuing.'**
  String get mustAcceptTermsBeforeContinuing;

  /// No description provided for @consentTimestampMissing.
  ///
  /// In en, this message translates to:
  /// **'Consent timestamp missing. Please accept Terms & Conditions again.'**
  String get consentTimestampMissing;

  /// No description provided for @pleaseConfirmAvailabilityBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your availability before continuing.'**
  String get pleaseConfirmAvailabilityBeforeContinuing;

  /// No description provided for @pleaseAdd3PreferredSlots.
  ///
  /// In en, this message translates to:
  /// **'Please add at least 3 preferred slots on different days.'**
  String get pleaseAdd3PreferredSlots;

  /// No description provided for @selectHomeOrOfficePhysicalVisit.
  ///
  /// In en, this message translates to:
  /// **'Select home or office for the physical visit.'**
  String get selectHomeOrOfficePhysicalVisit;

  /// No description provided for @couldNotStartPaymentTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not start payment. Please try again.'**
  String get couldNotStartPaymentTryAgain;

  /// No description provided for @paymentRecordedSubmitNow.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded. You can submit your booking now.'**
  String get paymentRecordedSubmitNow;

  /// No description provided for @couldNotStartPayment.
  ///
  /// In en, this message translates to:
  /// **'Could not start payment.'**
  String get couldNotStartPayment;

  /// No description provided for @maxPreferredSlots.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 6 preferred slots.'**
  String get maxPreferredSlots;

  /// No description provided for @appointmentDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Appointment details'**
  String get appointmentDetailsTitle;

  /// No description provided for @timeToBeConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Time to be confirmed'**
  String get timeToBeConfirmed;

  /// No description provided for @specialistPendingAssignment.
  ///
  /// In en, this message translates to:
  /// **'Specialist · pending assignment'**
  String get specialistPendingAssignment;

  /// No description provided for @couldNotOpenSessionLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open the session link'**
  String get couldNotOpenSessionLink;

  /// No description provided for @cancelThisAppointmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this appointment?'**
  String get cancelThisAppointmentTitle;

  /// No description provided for @cancelThisAppointmentBody.
  ///
  /// In en, this message translates to:
  /// **'Your specialist will be notified. You can re-book any time afterwards.'**
  String get cancelThisAppointmentBody;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @cancelAppointment.
  ///
  /// In en, this message translates to:
  /// **'Cancel appointment'**
  String get cancelAppointment;

  /// No description provided for @couldNotCancelTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel — please try again.'**
  String get couldNotCancelTryAgain;

  /// No description provided for @appointmentSection.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get appointmentSection;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @paymentSection.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentSection;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @setByAdmin.
  ///
  /// In en, this message translates to:
  /// **'Set by admin'**
  String get setByAdmin;

  /// No description provided for @completePaymentToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Complete payment to confirm this session.'**
  String get completePaymentToConfirm;

  /// No description provided for @notesAndInstructions.
  ///
  /// In en, this message translates to:
  /// **'Notes & instructions'**
  String get notesAndInstructions;

  /// No description provided for @missedSessionHelp.
  ///
  /// In en, this message translates to:
  /// **'You missed this session. Reschedule to keep your care plan on track, or chat with our team if you need help.'**
  String get missedSessionHelp;

  /// No description provided for @payAndConfirm.
  ///
  /// In en, this message translates to:
  /// **'Pay & Confirm'**
  String get payAndConfirm;

  /// No description provided for @sessionNotYetJoinable.
  ///
  /// In en, this message translates to:
  /// **'Session not yet joinable'**
  String get sessionNotYetJoinable;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statusMissed;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get statusScheduled;

  /// No description provided for @statusAwaitingPaymentLower.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get statusAwaitingPaymentLower;

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
