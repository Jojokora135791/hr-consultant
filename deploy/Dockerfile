# HR-консультант — кастомный образ n8n с petrovich (склонение ФИО в .docx)
# adm-zip уже входит в n8n; petrovich ставим глобально, чтобы task-runner его нашёл.
FROM n8nio/n8n:latest

USER root
RUN npm install -g petrovich
USER node

# adm-zip — рендер .docx; petrovich — склонение ФИО (нода «Объединить значения»)
ENV NODE_FUNCTION_ALLOW_EXTERNAL=adm-zip,petrovich
