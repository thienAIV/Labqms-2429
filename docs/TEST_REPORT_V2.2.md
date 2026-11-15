# Báo cáo kiểm thử v2.2.0-rc.1

- PASS: giải nén ZIP nguồn hiện tại; quét secrets tĩnh; TypeScript `tsc -b` thành công.
- PASS: migration 0016–0017 có transaction, `if not exists` cho bảng/policy và không seed nội dung pháp lý.
- PASS: UI có dashboard chương, yêu cầu/minh chứng, workflow tài liệu, AI request, upload/version, CAPA, thiết bị, nhiệm vụ, báo cáo, Realtime và offline queue.
- BLOCKED: Vite bundle cục bộ do npm proxy tải thiếu Rollup; phải dùng Vercel build sạch.
- BLOCKED: AI runtime cho đến khi quản trị viên chọn nhà cung cấp và nhập ba Supabase secrets.
- BLOCKED: camera QR đa trình duyệt và ký số PKI công cộng; token QR thủ công và chữ ký xác nhận nội bộ hoạt động.
- NOT IMPLEMENTED: seed tiêu chí pháp lý. Đây là chủ ý an toàn, chờ quản trị viên xác minh phụ lục chính thức.
