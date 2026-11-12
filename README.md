# LabQMS 2429 v2.0.0-rc.1
Ứng dụng web độc lập React/TypeScript/Vite + Supabase. Không chứa dữ liệu pháp lý 2429 chưa xác minh, khóa bí mật hoặc dữ liệu demo trình bày như thật.

## Chạy
`npm install` → tạo `.env.local` từ `.env.example` → `npm run dev`.

## Build
`npm run build`.

## Triển khai
Vercel dùng Vite và hai biến `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`. Supabase migrations chạy tuần tự; Edge Function deploy với JWT verification.

## Giới hạn công bố
QR camera, offline sync đầu-cuối, AI thật và báo cáo xuất file vẫn bị gắn nhãn chưa triển khai; không được tuyên bố đã hoạt động.
