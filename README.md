# LabQMS 2429
Ứng dụng web độc lập quản lý chất lượng phòng xét nghiệm.

## Trạng thái
- Frontend React + TypeScript + Vite đã chuẩn hóa.
- Không ghi cứng khóa bí mật.
- Supabase chỉ được kích hoạt khi có biến môi trường.
- Dữ liệu pháp lý tiêu chí chưa được nhập. Không dùng dữ liệu minh họa để tính điểm.
- Migration 0001 tạo nền tảng tối thiểu, bật RLS và chỉ cho tài khoản approved đọc chương/tiêu chí.

## Chạy cục bộ
`npm install` rồi `npm run dev`.

## Biến môi trường
Sao chép `.env.example` thành `.env.local` và nhập Project URL cùng Publishable Key. Không đưa service_role key vào frontend.
