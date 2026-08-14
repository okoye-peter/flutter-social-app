import nodemailer from 'nodemailer';

const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM } = process.env;

const transporter = SMTP_HOST
  ? nodemailer.createTransport({
      host: SMTP_HOST,
      port: Number(SMTP_PORT ?? 587),
      secure: Number(SMTP_PORT ?? 587) === 465,
      auth: SMTP_USER && SMTP_PASS ? { user: SMTP_USER, pass: SMTP_PASS } : undefined,
    })
  : null;

export async function sendMail(to: string, subject: string, html: string): Promise<void> {
  if (!transporter) {
    console.log(`[email:dev] Skipping real send (no SMTP_HOST configured). To: ${to}`);
    console.log(`[email:dev] Subject: ${subject}`);
    console.log(`[email:dev] Body:\n${html}`);
    return;
  }

  await transporter.sendMail({
    from: SMTP_FROM ?? 'no-reply@socialapp.local',
    to,
    subject,
    html,
  });
}
