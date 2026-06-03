import '../services/api_service.dart';

bool paymentCompleted(PaymentDto? payment) {
  final st = (payment?.status ?? '').toLowerCase().trim();
  return st == 'paid' || st == 'completed' || st == 'success' || st == 'successful';
}

bool paymentInReview(PaymentDto? payment) {
  final st = (payment?.status ?? '').toLowerCase().trim();
  final hasProof = (payment?.proofSubmittedAt ?? '').trim().isNotEmpty;
  return st == 'in_review' ||
      st == 'in-review' ||
      st == 'pending_review' ||
      st == 'proof_submitted' ||
      (hasProof && !paymentCompleted(payment));
}

/// Client may submit/finalize booking after paying or submitting proof for review.
bool paymentReadyForBooking(PaymentDto? payment) {
  return paymentCompleted(payment) || paymentInReview(payment);
}
