"""
Mattermost-бот на mmpy_bot — вход HR-ассистента.

Зачем mmpy_bot, а не свой WS: у Mattermost нет n8n-триггера, а наш Node-коннектор
рвался на 1006 (reverse-proxy Контура капризничает с сырым WebSocket). mmpy_bot
(через mattermostdriver) сам корректно держит хендшейк/реконнект/пинги — так делает
коллега внутри, работает локально.

Логика: ловим ЛС боту → POST в n8n Webhook. Ответ бот НЕ постит — это делает сам n8n
нодой /api/v4/posts (n8n на testkontur.ru до локального бота не достучится, поэтому
двустороннюю схему через webhook бота не используем).

Живёт локально (как у коллеги) либо в Docker внутри контура.
"""
import os
import asyncio

from mmpy_bot import Bot, Settings
from plugin import N8nBridge

# Python 3.14 больше не создаёт event loop автоматически в get_event_loop(),
# а mattermostautodriver его дёргает → создаём и ставим loop заранее (как у коллеги).
loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)


def _bool(name: str, default: str = "false") -> bool:
    return os.environ.get(name, default).strip().lower() != "false"


bot = Bot(
    settings=Settings(
        MATTERMOST_URL=os.environ.get("MM_BASE_URL", "https://chat.skbkontur.ru"),
        MATTERMOST_PORT=int(os.environ.get("MM_PORT", "443")),
        BOT_TOKEN=os.environ["MM_BOT_TOKEN"],
        BOT_TEAM=os.environ.get("MM_TEAM", "Kontur"),
        # внутренний CA — коллеги гоняют с SSL_VERIFY=False
        SSL_VERIFY=_bool("MM_SSL_VERIFY", "false"),
        DEBUG=_bool("DEBUG", "true"),
    ),
    plugins=[N8nBridge()],
)

if __name__ == "__main__":
    bot.run()
