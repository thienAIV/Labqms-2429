# LabQMS 2429 v1.1.0
Ứng dụng React/TypeScript/Vite kết nối Supabase cho Bệnh Viện Mặt Trời Phú Quốc - Khoa Xét Nghiệm.

## Bổ sung v1.1
- Dashboard truy vấn dữ liệu thật.
- Quản trị và phê duyệt người dùng bằng RPC có kiểm tra quyền.
- Danh mục tài liệu thật, tạo bản nháp trong phạm vi đơn vị.
- Ghi nhận sự không phù hợp và danh sách CAPA.
- Migration 0009 hoàn thiện phạm vi người dùng và policy đọc CAPA.

Chạy migration 0009 sau 0001-0008. Không đưa `.env`, service role key hoặc secret key lên GitHub.
