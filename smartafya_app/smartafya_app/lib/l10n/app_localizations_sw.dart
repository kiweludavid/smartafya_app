// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get languageTitle => 'Lugha';

  @override
  String get languageSystem => 'Chaguo-msingi la mfumo';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSwahili => 'Kiswahili';

  @override
  String get somethingWentWrong => 'Kuna hitilafu imetokea';

  @override
  String get loginSubtitle => 'Afya Yako ya Akili Ina Umuhimu';

  @override
  String get email => 'Barua pepe';

  @override
  String get emailHelper => 'Tumia barua pepe ya akaunti yako';

  @override
  String get pleaseEnterEmail => 'Tafadhali weka barua pepe yako.';

  @override
  String get enterValidEmail => 'Weka anwani halali ya barua pepe.';

  @override
  String get password => 'Nenosiri';

  @override
  String get passwordHelper => 'Angalau herufi 8';

  @override
  String get pleaseEnterPassword => 'Tafadhali weka nenosiri lako.';

  @override
  String get passwordMinLength => 'Nenosiri lazima liwe na angalau herufi 8.';

  @override
  String get forgotPassword => 'Umesahau nenosiri?';

  @override
  String get login => 'Ingia';

  @override
  String get dontHaveAccount => 'Huna akaunti? ';

  @override
  String get signUp => 'Jisajili';

  @override
  String get loginFailed => 'Kuingia kumeshindikana. Tafadhali jaribu tena.';

  @override
  String get retry => 'Jaribu tena';

  @override
  String get continueAction => 'Endelea';

  @override
  String get open => 'Fungua';

  @override
  String get dismiss => 'Ondoa';

  @override
  String get reschedule => 'Panga upya';

  @override
  String get navHome => 'Nyumbani';

  @override
  String get navChat => 'Mazungumzo';

  @override
  String get navAppointments => 'Miadi';

  @override
  String get navProfile => 'Wasifu';

  @override
  String get roleClient => 'Mteja';

  @override
  String get roleDoctor => 'Daktari';

  @override
  String get couldNotLoadHomeData => 'Imeshindikana kupakia data ya nyumbani.';

  @override
  String get couldNotLoadProfileRetry =>
      'Imeshindikana kupakia wasifu wako. Tafadhali jaribu tena.';

  @override
  String get homeLoadTimedOut =>
      'Upakiaji wa nyumbani umeisha muda. Tafadhali jaribu tena.';

  @override
  String get couldNotLoadHomeRetry =>
      'Imeshindikana kupakia nyumbani. Tafadhali jaribu tena.';

  @override
  String get couldNotLoadSessionsPullToRetry =>
      'Imeshindikana kupakia vipindi. Vuta chini kujaribu tena.';

  @override
  String get couldNotLoadAllDataPullToRetry =>
      'Imeshindikana kupakia data yote. Vuta chini kujaribu tena.';

  @override
  String get couldNotLoadHomeDataPullToRetry =>
      'Imeshindikana kupakia data ya nyumbani. Vuta kujaribu tena.';

  @override
  String get sessionLinkNotAvailable => 'Kiungo cha kipindi bado hakipatikani';

  @override
  String get goodMorning => 'Habari za asubuhi';

  @override
  String get goodAfternoon => 'Habari za mchana';

  @override
  String get goodEvening => 'Habari za jioni';

  @override
  String get greetingThere => 'rafiki';

  @override
  String greetingWithName(String greeting, String name) {
    return '$greeting, $name 👋';
  }

  @override
  String get careTodaySummary => 'Haya ndiyo yote kwa huduma yako leo.';

  @override
  String get hello => 'Habari';

  @override
  String helloName(String name) {
    return 'Habari, $name';
  }

  @override
  String get doctorThankYou => 'Asante kwa kuwasaidia wateja leo.';

  @override
  String get howAreYouFeeling => 'Unajisikiaje leo?';

  @override
  String get upcomingSession => 'Kipindi Kinachofuata';

  @override
  String get startYourCare => 'Anza huduma yako';

  @override
  String get bookFirstConsultation => 'Weka miadi ya ushauri wako wa kwanza';

  @override
  String get consultation => 'Ushauri';

  @override
  String get joinSession => 'Jiunge na Kipindi';

  @override
  String get bookConsultation => 'Weka Miadi ya Ushauri';

  @override
  String get videoConsultation => 'Ushauri wa Video';

  @override
  String get audioConsultation => 'Ushauri wa Sauti';

  @override
  String get physicalConsultation => 'Ushauri wa Ana kwa Ana';

  @override
  String get onlineConsultation => 'Ushauri mtandaoni';

  @override
  String get audioConsultationLower => 'Ushauri wa sauti';

  @override
  String get inPersonVisit => 'Ziara ana kwa ana';

  @override
  String setupYourCare(int completed, int total) {
    return 'Sanidi huduma yako ($completed/$total imekamilika)';
  }

  @override
  String get fillHealthForm => 'Jaza fomu ya afya';

  @override
  String get bookSession => 'Weka miadi ya kipindi';

  @override
  String get makePayment => 'Fanya malipo';

  @override
  String get quickActions => 'Vitendo vya Haraka';

  @override
  String get quickActionsLower => 'Vitendo vya haraka';

  @override
  String get more => 'Zaidi';

  @override
  String get bookConsultationSubtitle => 'Anza kipindi kipya';

  @override
  String get myAppointments => 'Miadi Yangu';

  @override
  String get viewSchedule => 'Angalia ratiba';

  @override
  String get scheduleWithSpecialist => 'Panga na mtaalamu';

  @override
  String get viewAndManage => 'Angalia na simamia';

  @override
  String get joinSessionSubtitle => 'Fungua kiungo cha kipindi';

  @override
  String get chatSubtitle => 'Mazungumzo yako';

  @override
  String get medicalRecords => 'Rekodi za Matibabu';

  @override
  String get yourHistory => 'Historia yako';

  @override
  String sessionCreditBanner(String amount) {
    return 'Una salio la kipindi la $amount kutokana na kipindi cha kwanza ulichokosa. Itatumika kwenye kipindi chako kinachofuata kinachostahili malipo.';
  }

  @override
  String get youMissedSession => 'Umekosa kipindi';

  @override
  String withDoctor(String name) {
    return 'Na $name';
  }

  @override
  String get getHelp => 'Pata msaada';

  @override
  String sessionPosition(int current, int total) {
    return 'Kipindi $current kati ya $total';
  }

  @override
  String get startNewConsultation => 'Anza Ushauri Mpya';

  @override
  String get noUpcomingAppointments => 'Hakuna miadi inayofuata';

  @override
  String get bookConsultationToStart => 'Weka miadi ya ushauri kuanza.';

  @override
  String get continueConversation => 'Endelea Mazungumzo';

  @override
  String get chatWithSpecialist => 'Zungumza na mtaalamu wako';

  @override
  String get recently => 'Hivi karibuni';

  @override
  String get doctorLabel => 'Daktari';

  @override
  String get specialtyLabel => 'Utaalamu';

  @override
  String get sessionLabel => 'Kipindi';

  @override
  String get dateTimeLabel => 'Tarehe na Muda';

  @override
  String get viewDetails => 'Angalia Maelezo';

  @override
  String get joinNow => 'Jiunge Sasa';

  @override
  String get specialistAssigned => 'Mtaalamu ameteuliwa';

  @override
  String get awaitingMatch => 'Inasubiri mechi';

  @override
  String get mentalHealthSpecialist => 'Mtaalamu wa afya ya akili';

  @override
  String get waitingForSpecialist => 'Inasubiri uthibitisho wa mtaalamu.';

  @override
  String get verifyingPayment =>
      'Tunathibitisha malipo yako — tutakujulisha hivi karibuni.';

  @override
  String sessionStartsInMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
      one: '1',
    );
    return 'Kipindi chako kinaanza baada ya dakika $_temp0.';
  }

  @override
  String sessionStartsInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
      one: '1',
    );
    return 'Kipindi chako kinaanza baada ya saa $_temp0.';
  }

  @override
  String get statusCompleted => 'Imekamilika';

  @override
  String get statusConfirmed => 'Imethibitishwa';

  @override
  String get statusInReview => 'Inakaguliwa';

  @override
  String get statusAwaitingPayment => 'Inasubiri Malipo';

  @override
  String get statusPending => 'Inasubiri';

  @override
  String get tbd => 'Haijabainishwa';

  @override
  String get emDash => '—';
}
