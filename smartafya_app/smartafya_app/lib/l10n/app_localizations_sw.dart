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
  String get signupSubtitle =>
      'Tengeneza akaunti yako na uanze safari yako ya ustawi wa afya ya akili';

  @override
  String get accountCreatedSuccessfully =>
      'Akaunti imetengenezwa kwa mafanikio.';

  @override
  String get signupFailed => 'Usajili umeshindikana. Tafadhali jaribu tena.';

  @override
  String get fullName => 'Jina kamili';

  @override
  String get fullNameHelper => 'Tumia jina lako halisi kwa wasifu wako';

  @override
  String get pleaseEnterFullName => 'Tafadhali weka jina lako kamili.';

  @override
  String get nameMinLength => 'Jina liwe na angalau herufi 3.';

  @override
  String get emailSignupHelper =>
      'Tutatumia barua pepe hii kuthibitisha akaunti';

  @override
  String get phoneNumber => 'Namba ya simu';

  @override
  String get phoneHelper => 'Jumuisha kodi ya nchi (mf. +255...)';

  @override
  String get pleaseEnterPhone => 'Tafadhali weka namba yako ya simu.';

  @override
  String get enterValidPhone => 'Weka namba halali ya simu.';

  @override
  String get passwordSignupHelper =>
      'Herufi 8+, herufi kubwa 1, na alama maalum 1';

  @override
  String get passwordStrengthHint =>
      'Tumia herufi 8+ zikiwa na herufi kubwa 1 na alama maalum 1.';

  @override
  String get confirmPassword => 'Thibitisha nenosiri';

  @override
  String get confirmPasswordHelper => 'Weka tena nenosiri lako';

  @override
  String get pleaseConfirmPassword => 'Tafadhali thibitisha nenosiri lako.';

  @override
  String get passwordsDoNotMatch => 'Nenosiri hazilingani.';

  @override
  String get alreadyHaveAccount => 'Tayari una akaunti? ';

  @override
  String get role => 'Jukumu';

  @override
  String get specialistType => 'Aina ya mtaalamu';

  @override
  String get specialistTypeHelper => 'Inahitajika kwa akaunti za daktari';

  @override
  String get pleaseSelectSpecialistType =>
      'Tafadhali chagua aina ya mtaalamu wako.';

  @override
  String get psychologist => 'Mwanasaikolojia';

  @override
  String get psychiatrist => 'Daktari wa akili';

  @override
  String get therapist => 'Mtaalamu wa tiba';

  @override
  String get cleric => 'Kiongozi wa dini';

  @override
  String get influencer => 'Mshawishi';

  @override
  String get doctor => 'Daktari';

  @override
  String get client => 'Mteja';

  @override
  String get appointmentsTitle => 'Miadi';

  @override
  String get upcoming => 'Inayofuata';

  @override
  String get completed => 'Imekamilika';

  @override
  String get missed => 'Iliyokosekana';

  @override
  String get failedToLoad => 'Imeshindikana kupakia.';

  @override
  String actionRequiredCount(int count) {
    return 'Hatua inahitajika ($count)';
  }

  @override
  String get careActionsBlurb =>
      'Mtaalamu wako ameomba uhamisho au hayupo. Gusa kuchagua: uhamisho au kupanga upya.';

  @override
  String get tapToResolveTransferReschedule =>
      'Gusa kutatua uhamisho/kupanga upya';

  @override
  String get followUpRequested => 'Ufuatiliaji umeombwa';

  @override
  String get suggestedDateDash => 'Tarehe iliyopendekezwa: —';

  @override
  String suggestedDateValue(String date) {
    return 'Tarehe iliyopendekezwa: $date';
  }

  @override
  String get doctorRecommendedAnotherSession =>
      'Daktari amependekeza kipindi kingine';

  @override
  String get tapToChooseAvailabilityProceed =>
      'Gusa kuchagua muda wako wa kupatikana na kuendelea.';

  @override
  String get followUpInitialDescription =>
      'Kipindi cha ufuatiliaji kimeombwa na daktari.';

  @override
  String get followUpBookingSubmitted => 'Ombi la ufuatiliaji limewasilishwa.';

  @override
  String get pendingRequests => 'Maombi yanayosubiri';

  @override
  String get allBookingsCoordination => 'Maombi yote (uratibu)';

  @override
  String bookingStatusTitle(String status) {
    return 'Ombi · $status';
  }

  @override
  String bookingTypePreferred(String type, String preferred) {
    return 'Aina: $type\nMuda uliopendekezwa: $preferred';
  }

  @override
  String get noUpcomingAppointments => 'Hakuna miadi inayofuata';

  @override
  String get noMissedSessions => 'Hakuna vipindi vilivyokosekana';

  @override
  String get noCompletedAppointmentsYet => 'Bado hakuna miadi iliyokamilika';

  @override
  String get bookConsultationToGetStarted => 'Weka miadi ya ushauri kuanza.';

  @override
  String get missedSessionsInfo =>
      'Kipindi kikihesabiwa kuwa kimekosekana, kitaonekana hapa. Unaweza kupanga upya muda wowote.';

  @override
  String get finishedConsultationsInfo =>
      'Ushauri uliokamilika utaonekana hapa.';

  @override
  String get bookAConsultation => 'Weka miadi ya ushauri';

  @override
  String get tbdShort => 'Haijabainishwa';

  @override
  String get specialistAssignedShort => 'Mtaalamu ameteuliwa';

  @override
  String get awaitingSpecialist => 'Inasubiri mtaalamu';

  @override
  String get ctaView => 'Angalia';

  @override
  String get ctaReschedule => 'Panga upya';

  @override
  String get ctaPay => 'Lipa';

  @override
  String get ctaJoin => 'Jiunge';

  @override
  String get ctaFeedback => 'Maoni';

  @override
  String get paymentPaid => 'Imelipwa';

  @override
  String get paymentInReview => 'Inakaguliwa';

  @override
  String get paymentNeeded => 'Malipo yanahitajika';

  @override
  String get bookingIntro =>
      'Jaza maelezo hapa chini. Majibu yako hutusaidia kukulinganisha na kujiandaa kwa kipindi chako.';

  @override
  String get termsAndConditions => 'Vigezo na Masharti';

  @override
  String get termsBody =>
      'Kwa kuwasilisha fomu hii, unathibitisha kuwa taarifa unazotoa ni sahihi kadri unavyojua. Majibu yako yanaweza kupitiawa na timu yako ya huduma ili kujiandaa kwa kipindi chako. Ikiwa una dharura, wasiliana na huduma za dharura mara moja.';

  @override
  String lastAccepted(String timestamp) {
    return 'Mara ya mwisho kukubali: $timestamp';
  }

  @override
  String get acceptTermsContinue => 'Kubali masharti na endelea';

  @override
  String get viewTerms => 'Angalia Vigezo na Masharti';

  @override
  String get acceptTermsToEnableSubmission =>
      'Kubali Vigezo na Masharti hapo juu ili uweze kuwasilisha.';

  @override
  String get availabilityConfirmation => 'Uthibitisho wa kupatikana';

  @override
  String get confirmAttendSelectedTimes =>
      'Nathibitisha ninaweza kuhudhuria katika nyakati zilizochaguliwa.';

  @override
  String get confirmAvailabilityToEnable =>
      'Thibitisha kupatikana ili uweze kuwasilisha.';

  @override
  String get stateOfMind => 'Hali ya hisia';

  @override
  String get describeCurrentConcerns => 'Eleza changamoto zako za sasa';

  @override
  String get pleaseAddMoreDetail =>
      'Tafadhali ongeza maelezo zaidi (angalau aya fupi).';

  @override
  String get whoShouldAttendYou => 'Nani akuhudumie?';

  @override
  String get whoShouldAttendHelp =>
      'Chagua mwanasaikolojia, daktari wa akili, mtaalamu wa tiba, kiongozi wa dini, au hata mshauri maarufu. Humwoni unayemtafuta? Tumia “Mpangilio maalum” ndani ya kichaguzi.';

  @override
  String get sessionType => 'Aina ya kipindi';

  @override
  String get audio => 'Sauti';

  @override
  String get video => 'Video';

  @override
  String get physical => 'Ana kwa ana';

  @override
  String get sessionTypeVisitSite => 'Aina ya kipindi (eneo la ziara)';

  @override
  String get homeVisit => 'Ziara nyumbani';

  @override
  String get officeClinic => 'Ofisi / kliniki';

  @override
  String get duration => 'Muda';

  @override
  String get preferredDatesTimes =>
      'Tarehe na nyakati unazopendelea (angalau 3)';

  @override
  String get preferredDatesHelp =>
      'Ongeza angalau nafasi 3 katika siku tofauti. Kila nafasi hutumia muda uliochagua kama urefu wa kipindi.';

  @override
  String get addSlot => 'Ongeza nafasi';

  @override
  String get visitLocation => 'Eneo la ziara';

  @override
  String get visitLocationHelp => 'Timu ya huduma ikutane nawe wapi?';

  @override
  String get street => 'Mtaa';

  @override
  String get streetHint => 'mf. Masaki Peninsula, Plot 12';

  @override
  String get enterStreetOrArea => 'Weka mtaa au eneo lako.';

  @override
  String get city => 'Jiji';

  @override
  String get cityHint => 'mf. Dar es Salaam';

  @override
  String get enterCity => 'Weka jiji lako.';

  @override
  String get selectedSpecialist => 'Mtaalamu aliyechaguliwa';

  @override
  String get lockedForThisBooking => 'Imefungwa kwa ombi hili';

  @override
  String get chooseYourSpecialist => 'Chagua mtaalamu wako';

  @override
  String get browseSpecialistsHelp =>
      'Tafuta wanasaikolojia, viongozi wa dini, washawishi na wengine — au acha Smart Afya ikulinganishe.';

  @override
  String get smartAfyaMatch => 'Ulinganisho wa Smart Afya';

  @override
  String get nextAvailableSpecialist => 'Mtaalamu anayepatikana anayekufaa';

  @override
  String get smartAfyaSpecialist => 'Mtaalamu wa Smart Afya';

  @override
  String get specialArrangement => 'Mpangilio maalum';

  @override
  String get adminWillCoordinate => 'msimamizi ataratibu';

  @override
  String get noPreference => 'Hakuna upendeleo';

  @override
  String get matchAnyoneAvailable =>
      'Smart Afya itakulinganisha na yeyote anayepatikana';

  @override
  String get change => 'Badilisha';

  @override
  String get clear => 'Ondoa';

  @override
  String get physicalPriceNegotiable =>
      'Bei ya kipindi cha ana kwa ana inaweza kujadiliwa (msimamizi + mteja).';

  @override
  String estimatedPrice(String price) {
    return 'Makadirio ya bei: $price';
  }

  @override
  String get submitBooking => 'Wasilisha ombi';

  @override
  String get acceptTermsToSubmit => 'Kubali masharti ili kuwasilisha';

  @override
  String get confirmAvailabilityToSubmit =>
      'Thibitisha kupatikana ili kuwasilisha';

  @override
  String get add3PreferredDatesToContinue =>
      'Ongeza tarehe 3 unazopendelea kuendelea';

  @override
  String get completePaymentToSubmit => 'Kamilisha malipo ili kuwasilisha';

  @override
  String get paymentReceived => 'Malipo yamepokelewa';

  @override
  String get paymentRequired => 'Malipo yanahitajika';

  @override
  String get canSubmitBookingNow =>
      'Sasa unaweza kuwasilisha ombi lako. Msimamizi atathibitisha na kupanga.';

  @override
  String payBeforeSubmitting(String price) {
    return 'Lipa $price kabla ya kuwasilisha. Pakia uthibitisho au maliza malipo ya simu/benki.';
  }

  @override
  String get payNow => 'Lipa sasa';

  @override
  String get mustAcceptTermsBeforeContinuing =>
      'Lazima ukubali Vigezo na Masharti kabla ya kuendelea.';

  @override
  String get consentTimestampMissing =>
      'Muda wa ridhaa haupo. Tafadhali kubali Vigezo na Masharti tena.';

  @override
  String get pleaseConfirmAvailabilityBeforeContinuing =>
      'Tafadhali thibitisha kupatikana kabla ya kuendelea.';

  @override
  String get pleaseAdd3PreferredSlots =>
      'Tafadhali ongeza angalau nafasi 3 za siku tofauti.';

  @override
  String get selectHomeOrOfficePhysicalVisit =>
      'Chagua nyumbani au ofisini kwa ziara ya ana kwa ana.';

  @override
  String get couldNotStartPaymentTryAgain =>
      'Imeshindikana kuanzisha malipo. Tafadhali jaribu tena.';

  @override
  String get paymentRecordedSubmitNow =>
      'Malipo yameandikwa. Sasa unaweza kuwasilisha ombi lako.';

  @override
  String get couldNotStartPayment => 'Imeshindikana kuanzisha malipo.';

  @override
  String get maxPreferredSlots => 'Unaweza kuongeza hadi nafasi 6.';

  @override
  String get appointmentDetailsTitle => 'Maelezo ya miadi';

  @override
  String get timeToBeConfirmed => 'Muda utathibitishwa';

  @override
  String get specialistPendingAssignment => 'Mtaalamu · anasubiri kuteuliwa';

  @override
  String get couldNotOpenSessionLink =>
      'Imeshindikana kufungua kiungo cha kipindi';

  @override
  String get cancelThisAppointmentTitle => 'Unataka kughairi miadi hii?';

  @override
  String get cancelThisAppointmentBody =>
      'Mtaalamu wako ataarifiwa. Unaweza kuweka miadi tena muda wowote baadaye.';

  @override
  String get keep => 'Acha ilivyo';

  @override
  String get cancelAppointment => 'Ghairi miadi';

  @override
  String get couldNotCancelTryAgain =>
      'Imeshindikana kughairi — tafadhali jaribu tena.';

  @override
  String get appointmentSection => 'Miadi';

  @override
  String get dateLabel => 'Tarehe';

  @override
  String get timeLabel => 'Muda';

  @override
  String get typeLabel => 'Aina';

  @override
  String get statusLabel => 'Hali';

  @override
  String get paymentSection => 'Malipo';

  @override
  String get amountLabel => 'Kiasi';

  @override
  String get setByAdmin => 'Kimewekwa na msimamizi';

  @override
  String get completePaymentToConfirm =>
      'Kamilisha malipo ili kuthibitisha kipindi hiki.';

  @override
  String get notesAndInstructions => 'Maelezo na maelekezo';

  @override
  String get missedSessionHelp =>
      'Umekosa kipindi hiki. Panga upya ili uendelee na mpango wako wa huduma, au zungumza nasi ikiwa unahitaji msaada.';

  @override
  String get payAndConfirm => 'Lipa na Thibitisha';

  @override
  String get sessionNotYetJoinable => 'Bado huwezi kujiunga na kipindi';

  @override
  String get statusCancelled => 'Imeghairiwa';

  @override
  String get statusMissed => 'Imeikosekana';

  @override
  String get statusInProgress => 'Inaendelea';

  @override
  String get statusScheduled => 'Imepangwa';

  @override
  String get statusAwaitingPaymentLower => 'Inasubiri malipo';

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
