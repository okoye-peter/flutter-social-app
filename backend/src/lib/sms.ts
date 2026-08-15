const { SMS_API_KEY } = process.env;

/// No SMS provider is wired up yet — logs to the console in dev so the OTP
/// flow is fully testable locally. Set SMS_API_KEY and fill in a real
/// provider call (Twilio, Termii, etc.) here before shipping phone OTPs.
export async function sendSms(to: string, message: string): Promise<void> {
  if (!SMS_API_KEY) {
    console.log(`[sms:dev] Skipping real send (no SMS_API_KEY configured). To: ${to}`);
    console.log(`[sms:dev] Message: ${message}`);
    return;
  }

  throw new Error('SMS provider not configured — implement sendSms for your chosen provider');
}
