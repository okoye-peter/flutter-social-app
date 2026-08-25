import type { Request, Response } from 'express';
import * as conversationService from '../services/conversation.js';
import * as messageService from '../services/message.js';
import * as messageReadService from '../services/message-read.js';
import * as pinService from '../services/pin.js';
import * as callService from '../services/call.js';

type ListQuery = { cursor?: string; limit?: string };

export async function createConversation(req: Request, res: Response) {
  const { type, participantId, name, visibility, memberIds } = req.body as {
    type?: string;
    participantId?: string;
    name?: string;
    visibility?: string;
    memberIds?: string[];
  };
  const conversation = await conversationService.createConversation({
    creatorId: req.userId!,
    type: type ?? 'DIRECT',
    participantId,
    name,
    visibility,
    memberIds,
    imageFile: req.file ? { buffer: req.file.buffer } : undefined,
  });
  res.status(201).json({ conversation });
}

export async function listMyConversations(req: Request, res: Response) {
  const page = await conversationService.listMyConversations(req.userId!, req.query as ListQuery);
  res.json(page);
}

export async function getConversation(req: Request, res: Response) {
  const conversation = await conversationService.getConversation((req.params.id as string), req.userId!);
  res.json({ conversation });
}

export async function updateConversation(req: Request, res: Response) {
  const { name, visibility } = req.body as { name?: string; visibility?: string };
  const conversation = await conversationService.updateConversation((req.params.id as string), req.userId!, {
    name,
    visibility,
    imageFile: req.file ? { buffer: req.file.buffer } : undefined,
  });
  res.json({ conversation });
}

export async function addMembers(req: Request, res: Response) {
  const { memberIds } = req.body as { memberIds: string[] };
  const conversation = await conversationService.addMembers((req.params.id as string), req.userId!, memberIds);
  res.json({ conversation });
}

export async function removeMember(req: Request, res: Response) {
  await conversationService.removeMember((req.params.id as string), req.userId!, (req.params.userId as string));
  res.status(204).end();
}

export async function leaveConversation(req: Request, res: Response) {
  await conversationService.leaveConversation((req.params.id as string), req.userId!);
  res.status(204).end();
}

export async function listMessages(req: Request, res: Response) {
  const page = await messageService.listMessages((req.params.id as string), req.userId!, req.query as ListQuery);
  res.json(page);
}

export async function sendMessage(req: Request, res: Response) {
  const { type, content, replyToId, mentionedUserIds, durationSeconds } = req.body as {
    type: string;
    content?: string;
    replyToId?: string;
    mentionedUserIds?: string[];
    durationSeconds?: string;
  };
  const message = await messageService.sendMessage({
    conversationId: (req.params.id as string),
    senderId: req.userId!,
    type,
    content,
    replyToId,
    durationSeconds,
    mentionedUserIds,
    file: req.file ? { buffer: req.file.buffer, mimetype: req.file.mimetype, size: req.file.size, originalname: req.file.originalname } : undefined,
  });
  res.status(201).json({ message });
}

export async function markRead(req: Request, res: Response) {
  const { upToMessageId } = req.body as { upToMessageId: string };
  const result = await messageReadService.markMessagesRead((req.params.id as string), req.userId!, upToMessageId);
  res.json(result);
}

export async function listPinned(req: Request, res: Response) {
  const result = await pinService.listPinned((req.params.id as string), req.userId!);
  res.json(result);
}

export async function listCalls(req: Request, res: Response) {
  const page = await callService.listCalls((req.params.id as string), req.userId!, req.query as ListQuery);
  res.json(page);
}
