"""
Плагин-мост: личное сообщение боту → POST в n8n Webhook.
"""
import os
import json
import logging

import aiohttp
from mmpy_bot import Plugin, listen_to

log = logging.getLogger("n8n-bridge")

N8N_WEBHOOK_URL = os.environ["N8N_WEBHOOK_URL"]


class N8nBridge(Plugin):
    @listen_to(".*", direct_only=True)
    async def handle_direct_message(self, message):
        # вытащить file_ids (фото-доказательства), если приложены
        file_ids = []
        sender_name = None
        try:
            data = message.body.get("data", {})
            sender_name = data.get("sender_name")
            post = json.loads(data.get("post", "{}"))
            file_ids = post.get("file_ids", []) or []
        except Exception:
            pass

        payload = {
            "channel_id": message.channel_id,
            "user_id": message.user_id,
            "sender_name": sender_name,
            "message": message.text,
            "file_ids": file_ids,
        }

        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(N8N_WEBHOOK_URL, json=payload) as resp:
                    if resp.status >= 400:
                        body = await resp.text()
                        log.error("n8n ответ %s: %s", resp.status, body)
                    else:
                        log.info("→ n8n: %s", (message.text or "")[:60])
        except Exception as e:
            log.error("не смог доставить в n8n: %s", e)
