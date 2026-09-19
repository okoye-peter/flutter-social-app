import { prisma } from '../prisma.js';
import { messaging } from '../firebase.js';

export interface CallPushPayload {
  callId: string;
  conversationId: string;
  type: 'VOICE' | 'VIDEO';
  initiatorId: string;
  initiatorName: string;
}

// Separate from sendNotification/createNotification on purpose: those
// already branch on 9 notification types and are "visible banner"
// semantics. This is "silent, data-only, must wake a backgrounded app to
// show a native incoming-call UI (CallKit/ConnectionService)" semantics —
// mixing the two risks regressing the other notification types.
//
// No top-level `notification` field: a data-only message is what lets the
// client's background handler run custom logic (show CallKit) instead of
// the OS auto-displaying a generic banner that would fight the native
// incoming-call UI.
export async function sendCallPush(userId: string, payload: CallPushPayload): Promise<void> {
  const rows = await prisma.deviceToken.findMany({ where: { userId } });
  const tokens = rows.map((row) => row.token);
  if (tokens.length === 0) return;

  try {
    await messaging.sendEachForMulticast({
      tokens,
      data: {
        type: 'CALL',
        callId: payload.callId,
        conversationId: payload.conversationId,
        callType: payload.type,
        initiatorId: payload.initiatorId,
        initiatorName: payload.initiatorName,
      },
      android: { priority: 'high' },
      apns: {
        headers: { 'apns-priority': '10', 'apns-push-type': 'background' },
        payload: { aps: { contentAvailable: true } },
      },
    });
  } catch {
    // Push failure must never block the invite flow — the socket
    // call:incoming emit (for foregrounded recipients) is unaffected.
  }
}
