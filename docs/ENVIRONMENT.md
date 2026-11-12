# Biến môi trường

Frontend Vercel dùng đúng hai biến công khai:

```text
VITE_SUPABASE_URL=
VITE_SUPABASE_PUBLISHABLE_KEY=
```

Không đưa `service_role`, Database Password hoặc khóa AI vào Vite/GitHub. Secrets phía máy chủ chỉ lưu trong Supabase Secrets.
