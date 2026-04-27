import type { Route } from '../types';
import { badRequest, json, serverError } from '../router';
import { withAuth } from '../middleware/auth';

type FeedbackBody = {
  message?: string;
  contact_platform?: string;
  contact_handle?: string;
};

const allowedPlatforms = new Set(['tg', 'whatsapp', 'ins', 'x']);
const telegramChatId = '-1001912953325';

export const feedbackRoutes: Route[] = [
  {
    method: 'POST',
    pattern: /^\/api\/v1\/feedback$/,
    handler: withAuth(async (req, env, ctx) => {
      const body = await req.json<FeedbackBody>().catch(() => null);
      if (!body) return badRequest('请求内容格式错误');

      const message = body.message?.trim() ?? '';
      const contactPlatform = body.contact_platform?.trim().toLowerCase() ?? '';
      const contactHandle = body.contact_handle?.trim() ?? '';

      if (!message) return badRequest('需求和反馈必填');
      if (message.length > 2000) return badRequest('需求和反馈不能超过 2000 字');
      if (!allowedPlatforms.has(contactPlatform)) return badRequest('联系方式平台无效');
      if (!contactHandle) return badRequest('联系方式必填');
      if (contactHandle.length > 160) return badRequest('联系方式不能超过 160 字');

      if (!env.TELEGRAM_BOT_TOKEN) {
        return serverError('反馈通道未配置');
      }

      const sent = await sendTelegramMessage(
        env.TELEGRAM_BOT_TOKEN,
        telegramChatId,
        formatFeedbackMessage({
          message,
          contactPlatform,
          contactHandle,
          appEnv: env.APP_ENV,
          accountId: ctx.account.id,
          nickName: ctx.account.nick_name,
          kitchenId: ctx.kitchen?.id,
        })
      );

      if (!sent.ok) {
        return serverError('反馈提交失败');
      }

      return json({ ok: true });
    }),
  },
];

function formatFeedbackMessage(input: {
  message: string;
  contactPlatform: string;
  contactHandle: string;
  appEnv: string;
  accountId: string;
  nickName: string;
  kitchenId?: string;
}): string {
  return [
    '新的需求反馈',
    `环境：${input.appEnv}`,
    `时间：${new Date().toISOString()}`,
    `账号：${input.nickName} (${input.accountId})`,
    `厨房：${input.kitchenId ?? '未进入厨房'}`,
    `联系方式：${input.contactPlatform} ${input.contactHandle}`,
    '',
    input.message,
  ].join('\n');
}

async function sendTelegramMessage(
  botToken: string,
  chatId: string,
  text: string
): Promise<{ ok: boolean }> {
  const response = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: 'POST',
    headers: { 'content-type': 'application/json; charset=utf-8' },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      disable_web_page_preview: true,
    }),
  });

  if (!response.ok) {
    console.error('Telegram sendMessage failed', {
      status: response.status,
      statusText: response.statusText,
    });
    return { ok: false };
  }

  return { ok: true };
}
