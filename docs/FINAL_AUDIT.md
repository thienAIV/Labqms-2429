# Kiểm kê cuối v1.2.0-rc.1

## Hoàn chỉnh và có bằng chứng
- React/TypeScript/Vite; Supabase client; Vercel Production Ready.
- Auth UI, pending gate, 12 chương, dashboard số đếm thật.
- Schema 0001-0009, RLS bật trên bảng nghiệp vụ, documents bucket private.
- Không còn số điểm/CAPA/người dùng mẫu trình bày như thật.

## Có nhưng chưa hoàn chỉnh
- Documents: tạo metadata bản nháp; chưa upload/version review/approval UI.
- CAPA: tạo và liệt kê nonconformity; chưa quản lý action/effectiveness UI đầy đủ.
- User admin: phê duyệt RPC; chưa khóa/mở khóa và audit UI.
- PWA: manifest/service worker cơ bản; thiếu icon và kiểm thử cài đặt.

## Schema có nhưng chưa có luồng sử dụng đầu-cuối
- Records/signatures, assessments, forms/QR, notifications, AI reviews/findings.

## Chưa xây dựng
- Equipment/location/task modules; signed URL Edge Function; AI thật; reports/export; Realtime subscriptions; QR camera scanner; offline sync worker; backup automation.

## Dữ liệu pháp lý
- Chưa có tiêu chí 2429 verified. Không được tính điểm hoặc mức chất lượng chính thức.
