EdgeSpace AI — Render deploy helper

Place these files at the repository ROOT, next to:
  flutter_app/
  backend/

Files:
  .gitignore
  render.yaml

IMPORTANT:
- Do NOT upload backend/.env to GitHub.
- Put GEMINI_API_KEY only in Render Environment Variables.
- Render Free filesystem is ephemeral, so backend/data/*.db is intentionally ignored.
