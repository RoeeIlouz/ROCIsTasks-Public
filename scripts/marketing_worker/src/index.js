/**
 * Cloudflare Worker: Telegram Webhook -> GitHub Actions Dispatch
 * Handles instant response to inline button taps [Approve] & [Skip]
 */
export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return new Response('ROCIs Telegram Webhook Worker is running.', { status: 200 });
    }

    try {
      // Optional security header check if secret token is configured
      const secretHeader = request.headers.get('X-Telegram-Bot-Api-Secret-Token');
      if (env.WEBHOOK_SECRET && secretHeader !== env.WEBHOOK_SECRET) {
        return new Response('Unauthorized', { status: 403 });
      }

      const update = await request.json();
      const callback = update.callback_query;

      if (!callback) {
        // Not an inline button click (could be normal message/command)
        return new Response('OK', { status: 200 });
      }

      const callbackId = callback.id;
      const callbackData = callback.data || '';
      const messageId = callback.message ? callback.message.message_id : null;
      const chatId = callback.message && callback.message.chat ? callback.message.chat.id : null;

      if (!callbackData.includes(':')) {
        return new Response('Invalid data format', { status: 200 });
      }

      const parts = callbackData.split(':');
      const action = parts[0];
      const draftId = parts[1];
      const isApprove = action === 'approve';

      // 1. Immediately acknowledge the button click so Telegram removes the loading clock
      if (env.TELEGRAM_BOT_TOKEN) {
        const answerText = isApprove
          ? 'Approved! Dispatching worker runner...'
          : 'Skipped.';
        await fetch('https://api.telegram.org/bot' + env.TELEGRAM_BOT_TOKEN + '/answerCallbackQuery', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            callback_query_id: callbackId,
            text: answerText
          })
        });

        // 2. Edit Telegram message to show action in-flight
        if (messageId && chatId) {
          const statusPrefix = isApprove
            ? '<b>Approval received! Launching auto-poster...</b>\n\n'
            : '<b>Draft Skipped</b>\n\n';

          const originalText = callback.message.text || '';
          await fetch('https://api.telegram.org/bot' + env.TELEGRAM_BOT_TOKEN + '/editMessageText', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              chat_id: chatId,
              message_id: messageId,
              text: statusPrefix + originalText.substring(0, 3800),
              parse_mode: 'HTML'
            })
          });
        }
      }

      // 3. Dispatch GitHub Actions workflow via repository_dispatch API
      if (env.GH_PAT) {
        const repoDispatchUrl = 'https://api.github.com/repos/RoeeIlouz/ROCIs-Tasks/dispatches';
        const dispatchRes = await fetch(repoDispatchUrl, {
          method: 'POST',
          headers: {
            'Accept': 'application/vnd.github.v3+json',
            'Authorization': 'Bearer ' + env.GH_PAT,
            'User-Agent': 'Cloudflare-Worker-ROCIs-Tasks'
          },
          body: JSON.stringify({
            event_type: 'telegram-approval',
            client_payload: {
              action: action,
              draft_id: draftId,
              message_id: messageId
            }
          })
        });

        if (!dispatchRes.ok) {
          const errText = await dispatchRes.text();
          console.error('GitHub Dispatch Error (' + dispatchRes.status + '): ' + errText);
        }
      }

      return new Response('Dispatched successfully', { status: 200 });
    } catch (err) {
      console.error('Worker error:', err);
      return new Response('Internal error: ' + err.message, { status: 500 });
    }
  }
};
